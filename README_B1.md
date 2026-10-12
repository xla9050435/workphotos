# 工作照片管理软件 · 项目说明（覆盖 B1–B6 全量）

> 工程目录：`D:\work_photos`（纯英文路径，规避 Android/Gradle 中文路径编译问题）
> 本文档整合了原「B1 批次说明」并扩展到完整 App。

## 一、这是什么

一款面向「工作时照片分类人群」的 Android 照片管理 App。核心铁律（D2/D4）：
**照片只以"引用"方式记录，永不复制或上传任何字节**——数据库只存 `AssetEntity.id`（或本地路径），
真实文件始终留在系统相册里。

## 二、五大功能 → 实现映射

| # | 需求 | 实现 |
|---|------|------|
| 1 | 软件内分类（一张照片可归多类）且可选不建真实文件夹 | 多对多关联表（D1）；本期只做**逻辑归类**，不创建系统目录（D2） |
| 2 | 快速标记已用/未用且外观明显区分 | `used_status` 字段 + 网格**灰度 + 绿/红角标 + 边框** |
| 3 | 只读相册导入，不加载照片内容进软件 | `photo_manager` 枚举相册，`MediaRef` 只存 `AssetEntity.id` |
| 4 | 快速分享到微信/QQ 等 | `share_plus` 系统 Sharesheet（`Share.shareXFiles`） |
| 5 | 大量照片打包 PDF/ZIP 发送 | `pdf` + `archive`，单次上限 200 张防 OOM（`kBatchLimit`） |

## 三、已确认决策（D1–D5）

- **D1**：一张照片可属于多个分类（多对多）。
- **D2**：本期只做逻辑归类，不创建真实文件夹。
- **D3**：本期不做云同步，但 `photos` 表预留 `sync_state` 字段，日后好加。
- **D4**：本期仅 Android（架构已留兼容，未来可加 Windows）。
- **D5**：打包 PDF 仅含图片与文件名，无备注/日期/水印。

## 四、技术栈

- Flutter 3.22+ / Dart 3.4+，Android 优先
- 状态管理：**Riverpod**；本地库：**Drift (SQLite)**；路由：**go_router**
- 关键依赖：`photo_manager`（只读相册）、`permission_handler`、`share_plus`、`pdf`、`printing`、
  `archive`、`photo_view`、`go_router`、`drift_dev` + `build_runner`

## 五、目录结构（节选）

```
photo_manager/
├── pubspec.yaml                 # name: work_photos（见第六节说明）
├── build_and_run.bat            # ★ 一键运行脚本（推荐日常使用，见第七节）
├── build_apk.bat                # ★ 一键打包 APK（可选，见第七节）
├── build_run.log                # 运行日志（build_and_run.bat 每次运行覆盖生成）
├── build_apk.log                # 打包日志（build_apk.bat 专用，与上面互不覆盖）
├── pubspec.yaml.scriptbak       # flutter create 前自动留的 pubspec 备份（首次生成）
├── tools/
│   ├── inject_permissions.ps1   # 权限注入逻辑（幂等，由 .bat 调用）
│   └── show_help.bat            # 中文提示显示（独立 .bat，理由见 7.4）
├── help_zh/                     # 脚本的中文提示文本（UTF-8，由 .bat 按步骤显示）
│   ├── 00_intro.txt ~ 07_apk.txt
│   └── 99_errors.txt            # 通用排错速查表
├── setup_b1.bat                 # 【历史】旧版一键脚本，已被 build_and_run.bat 取代
├── SCRIPTS_QA.md                # QA 审查清单与本机验收步骤
├── README_B1.md                 # 本文件
└── lib/
    ├── main.dart                # 入口：初始化 + Provider 注入 appDatabaseProvider
    ├── app.dart                 # MaterialApp 根（首页 = PermissionGate）
    ├── core/                    # constants / errors / utils(media_ref)
    ├── data/
    │   ├── models/              # photo / category / used_status
    │   ├── db/                  # app_database + tables(photos/categories/photo_category) + daos
    │   └── repositories/        # photo_repository / category_repository
    ├── providers/               # riverpod providers（含 PhotoFilter family）
    ├── features/
    │   ├── permission/          # 运行时权限闸门 → 授权后切 RouterApp
    │   ├── dashboard/           # 统计卡片
    │   ├── classify/            # 分类 CRUD + 底部归类弹层
    │   ├── import/              # 只读相册浏览 + 引用式导入
    │   ├── library/             # 网格（已用/未用视觉区分）+ 多选栏（分享入口）
    │   ├── detail/              # 大图 + 切换已用 + 单张分享
    │   ├── filters/             # 分类/已用未用筛选
    │   └── share/               # 分享面板 + packer(pdf/zip)
    ├── routing/                 # go_router 四分支 + /photo/:id
    └── widgets/                 # status_badge / thumbnail / app_scaffold
```

## 六、⚠️ 重要：包名与插件同名冲突（已修复）

本 App 的 Dart 包名原为 `photo_manager`，与第三方插件 `photo_manager`（pub.dev）**重名**。
Dart 中根包名与依赖同名时，`package:photo_manager/` 会解析到**根包**而非插件，导致 5 个文件对插件的
导入 `package:photo_manager/photo_manager.dart` 直接编译失败。

**修复**：App 包名改为 **`work_photos`**（`pubspec.yaml` 的 `name:`）。所有本地导入统一改为
`package:work_photos/...`；唯独真正指向插件的 5 处保留 `package:photo_manager/photo_manager.dart`
（`media_ref` / `thumbnail` / `album_browser` / `import_controller` / `import_page`）。
依赖行 `photo_manager: ^3.1.0` 保持不变。

> 仓库当前**没有 `android/` 目录**（`flutter create` 尚未运行），改名后再生成平台脚手架，包名一致，无残留问题。

## 七、本机运行 / 打包（优先用脚本，不要手动敲命令）

> **结论先行：日常使用只需要双击 `build_and_run.bat`。**
> 它把原来要手动敲的 5 条命令（flutter create → 注入权限 → pub get → build_runner → run）
> 串成了一条带错误检查、带中文说明、带日志的流水线。

### 7.1 运行 App（首次从零跑通全流程）

1. 保持 **Clash（或所用代理）开启**。脚本默认走 `127.0.0.1:7897`。
   > 端口若不同，用记事本打开 `build_and_run.bat`，改最上面的 `PROXY_PORT=7897` 那一行，保存后重跑。
2. 手机开 **USB 调试** 并用数据线连电脑（弹出「允许调试」要点允许）。
3. **双击 `build_and_run.bat`**，按窗口里的中文提示走即可。

脚本分 6 步执行，每步打印 `[n/6]` 进度，**每步都检查退出码，非 0 立即停下并说明原因**：

| 步骤 | 做什么 | 幂等 / 失败处理 |
|------|--------|-----------------|
| **0/6** | 环境体检：`flutter` / `dart` / `powershell` / `pubspec.yaml` 是否就位 | 缺任一项 → 停下并给出修复命令。`flutter` 不在 PATH 时自动回退到 `D:\flutter\bin` |
| **1/6** | `flutter doctor` | **只告警不中断**，真正致命错误由后续步骤自己报 |
| **2/6** | `flutter create --platforms android .` | `AndroidManifest.xml` 已存在则**跳过**；执行前自动备份 `pubspec.yaml`；`flutter create` 不覆盖 `lib/` |
| **3/6** | 注入 Android 读相册权限（`tools\inject_permissions.ps1`） | **幂等**：已存在的权限名跳过，不重复插入；首次修改自动留 `.bak` |
| **4/6** | `flutter pub get` | 失败即停（通常是代理端口不对 / 网络不通） |
| **5/6** | `dart run build_runner build --delete-conflicting-outputs` | 生成 `lib/data/db/app_database.g.dart`；失败即停并提示去日志里找 `Error` 行；旧命令 `flutter pub run` 自动兜底重试 |
| **6/6** | `flutter run` | 交互式；结束后打印总结，不强制退出（App 仍可独立使用） |

> 代理补充：Gradle **不认** `HTTP_PROXY`，只认 JVM 系统属性。
> 脚本因此额外设置了 `GRADLE_OPTS`（`-Dhttp.proxyHost/-Dhttps.proxyPort`），
> 否则首次 `flutter run` / `build apk` 下载 Gradle 与 Maven 依赖会卡到超时。
> 同时显式设置了 `JAVA_HOME`（`D:\jdk-17.0.14+7`）与 `ANDROID_SDK_DIR`。

第 3 步注入的两条权限（插在 `</manifest>` 之前，即 `</application>` **之外**）：

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```

### 7.2 日志位置（排错必看）

- 工程根目录的 **`build_run.log`** —— `build_and_run.bat` 每一步的**完整输出**都会写进去（每次运行重新覆盖）。
  出错时把这个文件发给开发人员即可定位。
- **`build_apk.log`** —— 打包脚本（`build_apk.bat`）的日志，**独立文件，不覆盖上面那个**。
  两个日志各对应一次运行，不会互相污染。
- `pubspec.yaml.scriptbak` —— 首次执行 `flutter create` 前自动留的备份。
- `AndroidManifest.xml.bak` —— 权限注入首次修改前的自动备份（仅第一次生成）。
- 第 6 步 `flutter run` 是交互式进程，输出直接打在屏幕上（不进日志），日志里只记录退出码。

### 7.3 打包 APK（可选）

- 双击 **`build_apk.bat`** → 默认打 **release** 包；
  传参打 debug 包：`build_apk.bat debug`（在 cmd 里执行）。
- 产物路径：**<code>build\app\outputs\flutter-apk\app-release.apk</code>**，脚本结束会直接列目录并打印安装方式。
- 同样带代理设置、同样的错误处理；日志写入 **`build_apk.log`**（**与运行日志分开，互不覆盖**）。

### 7.4 脚本实现上的几个关键约束（改脚本前必读）

这些不是风格偏好，而是**实测踩出来的坑**，请勿"顺手简化"：

1. **`.bat` 全文必须是纯 ASCII**。
   Windows 按系统 OEM 代码页（中文机器通常 GBK/936）解析 `.bat`，
   含中文会乱码甚至让整条命令语法失效。
   → 中文提示全部外置到 **`help_zh/*.txt`**（UTF-8），
   由 `tools\show_help.bat` 用 PowerShell 按 UTF-8 读出后打印。
   这样做**不需要 `chcp` 切换**，也就不会把控制台代码页改坏、
   影响后续 Flutter / Gradle 的中文输出。

2. **中文显示要放在独立的 `tools\show_help.bat` 里，不能写成 `call :showzh`**。
   cmd.exe 解析 `call :标签` 时会缓存字节偏移，经过若干次 `goto` 跳转后
   该缓存可能失效，导致 `call :showzh` 报
   「系统找不到指定的批处理标签」（同一个标签第一次成功、第二次失败）。
   调用**另一个 `.bat` 文件**没有这个问题，所以中文显示独立成文件。

3. **所有 `flutter` / `dart` 命令前面必须加 `call`**。
   这两个在 Windows 上都是 `.bat` 文件；在 `.bat` 里不加 `call` 直接调用，
   控制权会转移过去且**再也不返回**，脚本会在第一步之后静默结束。
   实测：不加 `call` 时脚本输出停在 `[1/6]` 之后，无任何报错。

4. **单行长度必须 < 255 字符**。
   超长行会让 cmd.exe 无法定位后面的 `call :标签`。
   所以 `:fail_*` 处理器的说明文字先拼进变量 `M`，再 `call :fail_step ... "%M%"`。

5. **文件必须是 CRLF 换行**。LF-only 的 `.bat` 会出现标签解析异常。

6. **不要用裸 `find` / `more`**。
   装了 Git for Windows / MSYS 时，PATH 里靠前的 `find` 是 Unix 版，
   参数完全不同，会直接开始扫描整个 C 盘并把脚本卡死。
   （脚本已改为不依赖它们：每步输出先写临时文件，再 `type` 到屏幕并追加进日志。）

### 7.5 `setup_b1.bat` 的状态

旧脚本 `setup_b1.bat` **保留作历史参考**，但**不要再用**：
它没有退出码检查、没有日志、权限注入不幂等（重复运行会插两遍），
且权限注入那段 PowerShell 内联命令存在引号转义风险。请统一改用 `build_and_run.bat`。

### 7.6 手工等价命令（仅在需要排查时用）

1. `flutter create --platforms android .`
2. 确认 `android/app/src/main/AndroidManifest.xml` 含上面两条 READ 权限
3. `flutter pub get`
4. `dart run build_runner build --delete-conflicting-outputs`
5. `flutter run`

## 八、本机验证时可能需微调的 API 假设点

代码**未经本机编译**（agent 沙箱无法运行 flutter/dart），以下四处为本机若报错最可能需对照官方文档微调的位置：

1. `share_plus` 7.x 的 `Share.shareXFiles(xfiles, text:)` 行为与参数。
2. `archive` 的 `ZipEncoder().encode(archive)` 返回 `Uint8List?`（已判空抛 `StateError`）。
3. `pdf` 的 `pw.Document().save()` 为 `Future<Uint8List>`。
4. `go_router` 的 `StatefulShellRoute.indexedStack` / `StatefulShellBranch` 签名（v13 可用）。

> 此外，若 `permission_handler` 在新版 Android 需 `POST_NOTIFICATIONS` 等附加声明，按官方文档补 `AndroidManifest.xml` 即可。

## 九、预期验收

授权相册权限后进入底部导航四页：**仪表盘**（总数/已用/未用/分类数统计）、**分类**（增删与归类）、
**导入**（只读浏览相册并勾选引用式导入）、**网格**（已用/未用明显区分 + 多选分享）。详情页支持大图查看、
切换已用状态、单张分享；多选后可直分享 / 打包 PDF / 打包 ZIP。
