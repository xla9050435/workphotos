package com.example.work_photos

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 应用主 Activity。
 *
 * 除承载 Flutter 引擎外，额外暴露一个 MethodChannel 供「引用式导入」页的相机
 * 快捷入口调用（见 CameraLauncher.dart）。
 *
 * 为什么用系统相机 Intent 而不是 App 内自建相机：
 * - 系统相机成像质量、对焦、HDR、闪光灯、视频录制等能力成熟且随 ROM 更新，
 *   自建 CameraX/Camera2 要重新实现一套预览 + 拍摄 + 编码，成本高、坑多；
 * - 用 ACTION_IMAGE_CAPTURE 无需申请 CAMERA 权限（由相机应用持有），
 *   应用侧少一道运行时授权门槛；
 * - 拍完由相机应用把文件写入我们给定的输出 Uri，进而进入媒体库，符合
 *   「引用式」定位（本 App 只读相册、不复制字节）。
 *
 * 输出 Uri 的获取按系统版本分两条分支（互不影响）：
 * - API >= 29（Android 10+，scoped storage）：必须走 MediaStore 插入一条 pending
 *   记录拿到 content:// Uri。scoped storage 明确禁止应用直接用 File 在公共
 *   DCIM 目录创建文件，所以旧方案在新系统上会静默失败。
 * - API <= 28（Android 9 及以下）：沿用 FileProvider + 公共 DCIM 直接建文件。
 */
class MainActivity : FlutterActivity() {

    companion object {
        /** MethodChannel 名（与 CameraLauncher.dart 保持一致）。 */
        private const val CHANNEL = "work_photos/camera"

        /** 方法名：拉起系统相机拍照。 */
        private const val METHOD_CAPTURE = "capturePhoto"

        /** startActivityForResult 的请求码（自定义，避免与 Flutter/插件冲突）。 */
        private const val REQUEST_CAPTURE = 0x0CA1

        /** 应用信息 / 打开链接通道（与 app_native.dart 的通道名一致）。 */
        private const val APP_CHANNEL = "work_photos/app"
    }

    /**
     * 等待相机结果的 MethodChannel 回调。
     *
     * 相机是另一个 Activity，必须异步等待；这里暂存唯一一个在途请求的回调，
     * 等 onActivityResult 回来后再 success。用「唯一在途」而非队列，是为了
     * 防止连点造成多个请求争用同一输出文件 / 重复回调。
     */
    private var pendingResult: MethodChannel.Result? = null

    /** FileProvider 模式（API<=28）下的输出文件（成功时触发扫描、失败时清理空文件）。 */
    private var pendingFile: File? = null

    /** MediaStore 模式（API>=29）下本次插入的 content:// Uri。 */
    private var pendingUri: Uri? = null

    /** 本次拍摄是否走 MediaStore pending 模式（onActivityResult 据此选择回传/清理逻辑）。 */
    private var pendingNeedsPublish: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    METHOD_CAPTURE -> launchCamera(result)
                    else -> result.notImplemented()
                }
            }

        // 应用信息 / 打开链接通道：读版本（PackageManager）+ 用系统浏览器开链接。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getVersion" -> result.success(currentVersionMap())
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrEmpty()) {
                            result.error("bad_args", "缺少 url 参数", null)
                        } else {
                            result.success(openUrl(url))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 读取当前 APK 版本：versionName（如 "1.3.1"）+ build 号（如 21）。
     *
     * versionCode 在 API 28 起推荐 longVersionCode，低版本回退（deprecated）versionCode。
     * 任何异常都降级为 ("0.0.0", 0)，不让 Dart 侧崩。
     */
    private fun currentVersionMap(): Map<String, Any> {
        val map = HashMap<String, Any>()
        try {
            val info = packageManager.getPackageInfo(packageName, 0)
            map["version"] = info.versionName ?: "0.0.0"
            map["build"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                info.versionCode
            }
        } catch (e: Exception) {
            map["version"] = "0.0.0"
            map["build"] = 0
        }
        return map
    }

    /** 用系统浏览器打开 [url]（ACTION_VIEW）；成功拉起返回 true。 */
    private fun openUrl(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** 创建输出 Uri 并拉起系统相机（按系统版本分流）。 */
    private fun launchCamera(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "已有拍摄任务在进行中", null)
            return
        }

        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            launchWithMediaStore(intent, result)
        } else {
            launchWithFileProvider(intent, result)
        }
    }

    /**
     * API >= 29（Android 10+）：走 MediaStore 插入 pending 记录。
     *
     * 为什么必须这样：scoped storage（API 29 起强制）禁止应用用 File 直接在公共
     * DCIM 目录创建/写入文件，旧 FileProvider 方案会在 insert/openFile 阶段失败，
     * 表现为「点了相机没反应」。正确做法是先向 MediaStore 申请一条待写入记录，
     * 拿到系统分配的 content:// Uri 交给相机写；拍摄完成后把 IS_PENDING 置 0
     * 才算正式发布到相册。
     *
     * IS_PENDING=1 的作用：插入后到拍摄完成前，这条记录对其它 App（含系统相册、
     * photo_manager）不可见，避免半成品 / 0 字节图片被提前收录；拍完置 0 才公开，
     * 取消则直接 delete，公共目录不留空条目。
     *
     * API 29+ 不需要 FileProvider，也不需要 WRITE_EXTERNAL_STORAGE——
     * 应用对自己通过 MediaStore 创建的媒体记录拥有写权限。
     */
    private fun launchWithMediaStore(intent: Intent, result: MethodChannel.Result) {
        val ts = System.currentTimeMillis()
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "WP_$ts.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                Environment.DIRECTORY_DCIM + "/WorkPhotos",
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val uri: Uri? = try {
            contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        } catch (e: Exception) {
            result.error("io", "创建媒体记录失败：${e.message}", null)
            return
        }
        if (uri == null) {
            result.error("io", "创建媒体记录失败（insert 返回 null）", null)
            return
        }

        intent.putExtra(MediaStore.EXTRA_OUTPUT, uri)
        intent.addFlags(
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        pendingUri = uri
        pendingNeedsPublish = true
        startCapture(intent, result) {
            // 拉起失败：清字段并删除刚插入的 pending 记录。
            pendingUri = null
            pendingNeedsPublish = false
            try {
                contentResolver.delete(uri, null, null)
            } catch (_: Exception) {
                // 忽略清理异常
            }
        }
    }

    /**
     * API <= 28（Android 9 及以下）：FileProvider + 公共 DCIM 直接建文件（原逻辑不变）。
     *
     * 为什么用 FileProvider：Android 7.0（API 24）起禁止把 file:// Uri 通过 Intent
     * 传给其它应用（FileUriExposedException）。FileProvider 把文件映射成一个带临时
     * 授权的 content:// Uri，相机据此安全写入。file_paths.xml 已配置 DCIM/ 前缀映射。
     */
    private fun launchWithFileProvider(intent: Intent, result: MethodChannel.Result) {
        val photoFile: File = try {
            createOutputFile()
        } catch (e: Exception) {
            result.error("io", "创建照片文件失败：${e.message}", null)
            return
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            photoFile,
        )

        intent.putExtra(MediaStore.EXTRA_OUTPUT, uri)
        intent.addFlags(
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        pendingFile = photoFile
        pendingNeedsPublish = false
        startCapture(intent, result) {
            // 拉起失败：清字段并删除 0 字节占位文件。
            pendingFile = null
            deleteIfEmpty(photoFile)
        }
    }

    /**
     * 统一 set pendingResult 并 startActivityForResult；拉起失败时执行 [onLaunchFailed]
     * 清理（两条分支清理内容不同），再以 no_camera 回错。
     */
    private fun startCapture(
        intent: Intent,
        result: MethodChannel.Result,
        onLaunchFailed: () -> Unit,
    ) {
        pendingResult = result
        try {
            startActivityForResult(intent, REQUEST_CAPTURE)
        } catch (e: Exception) {
            // 常见于设备无相机应用（ActivityNotFoundException）等。
            pendingResult = null
            onLaunchFailed()
            result.error("no_camera", "无法拉起系统相机：${e.message}", null)
        }
    }

    /**
     * 在公共 DCIM/WorkPhotos/ 下创建输出文件（仅 API<=28 使用）。
     *
     * 为什么落在公共 DCIM 而不是 getExternalFilesDir：
     * - DCIM 是媒体库（MediaStore）默认扫描目录，相机拍完写进去后，相册增量
     *   查询（photo_manager 读 MediaStore）才能立即看到；
     * - getExternalFilesDir（Android/data/...）属应用私有目录，不进系统相册。
     */
    private fun createOutputFile(): File {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            "WorkPhotos",
        )
        if (!dir.exists()) dir.mkdirs()
        return File(dir, "WP_${System.currentTimeMillis()}.jpg")
    }

    /** 删除仍为 0 字节的占位文件（API<=28 取消 / 拉起失败时清理）。 */
    private fun deleteIfEmpty(file: File?) {
        if (file != null && file.exists() && file.length() == 0L) {
            file.delete()
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CAPTURE) {
            // 其它请求码（如 photo_manager / permission_handler 的）照常转发给插件。
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingResult
        pendingResult = null
        val ok = resultCode == Activity.RESULT_OK

        if (pendingNeedsPublish) {
            // —— API>=29：MediaStore pending 模式 ——
            val uri = pendingUri
            pendingUri = null
            pendingNeedsPublish = false
            if (uri != null) {
                if (ok) {
                    // 拍摄完成：解除 pending，让这条媒体对相册/其它 App 可见。
                    val publish = ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 0)
                    }
                    try {
                        contentResolver.update(uri, publish, null, null)
                    } catch (_: Exception) {
                        // 解除 pending 失败不致命，文件通常已可读。
                    }
                } else {
                    // 取消 / 失败：删除 pending 记录，避免公共目录残留 0 字节空条目。
                    try {
                        contentResolver.delete(uri, null, null)
                    } catch (_: Exception) {
                        // 忽略清理异常
                    }
                }
            }
            result?.success(ok && uri != null)
            return
        }

        // —— API<=28：FileProvider 模式（行为与原实现完全一致）——
        val file = pendingFile
        pendingFile = null
        val fileOk = ok && file != null && file.exists() && file.length() > 0L
        if (fileOk && file != null) {
            // 主动触发一次媒体扫描，尽快让 MediaStore 收录该文件。
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf("image/jpeg"),
                null,
            )
        } else {
            deleteIfEmpty(file)
        }
        result?.success(fileOk)
    }
}
