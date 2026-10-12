import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// -----------------------------------------------------------------------------
// 统一抬高所有 Gradle 子项目的 compileSdkVersion（只升不降）
//
// 背景（为什么要改）：
//   Flutter 插件自带的 android/build.gradle 里写死了各自发布时的 compileSdkVersion。
//   本项目各插件实际取值为：share_plus 33、permission_handler_android 34、printing 34、
//   jni/jni_flutter 35、sqlite3_flutter_libs 35、photo_manager 36。
//   同时 Flutter 的 PluginHandler 会把引擎 embedding 以 api 依赖注入到每个插件子项目
//   （flutter_tools/gradle/.../plugins/PluginHandler.kt -> addEmbeddingDependencyToPlugin），
//   embedding 传递依赖的 AndroidX 库（androidx.window:window:1.2.0、
//   androidx.window:window-java:1.2.0、androidx.fragment:fragment:1.7.1 等）
//   要求使用方的 compileSdk >= 34。于是 :share_plus:checkReleaseAarMetadata 抛出
//   "15 issues were found when checking AAR metadata" 并中断 release 构建。
//
// 写法依据（为什么这样写能生效）：
//   1) gradle.properties 里有 android.newDsl=false，因此 AGP 9.1.0 注册到子项目上的
//      "android" 扩展是旧版 DSL 类型 com.android.build.gradle.LibraryExtension，
//      继承链为 LibraryExtension -> TestedExtension -> BaseExtension（已用 javap 核对
//      AGP 9.1.0 的 gradle-9.1.0.jar 字节码；AGP 自身的 @Deprecated 说明也写明
//      "not used for the public extensions when android.newDsl=true"，反之 newDsl=false
//      时用的就是它们）。所以可以用 BaseExtension 拿到扩展。
//      Flutter 自己的 FlutterPluginUtils.getLegacyAndroidExtension() 正是
//      project.extensions.findByType(BaseExtension::class.java)。
//   2) BaseExtension 上确有 getCompileSdkVersion(): String（形如 "android-33"）、
//      compileSdkVersion(Int) / compileSdkVersion(String)。
//   3) 本段 afterEvaluate 由根项目脚本注册，早于各子项目 apply AGP 时注册的同类回调，
//      因此 AGP 创建变体、生成 checkReleaseAarMetadata 时读到的已经是抬高后的值。
//   4) 只升不降：不会把已经用更高 SDK 的插件（如 photo_manager 的 36）反向拉低。
//
// 注意：若将来把 gradle.properties 的 android.newDsl 改成 true，AGP 9 的 public
//   extension 类型会换成 com.android.build.api.dsl.*，此时 BaseExtension 取不到
//   （findByType 返回 null），本段会静默失效，需要改用 LibraryExtension.compileSdk。
//
// 不要删除本段：删掉后任何 compileSdk < 34 的插件都会让 release 构建失败。
// -----------------------------------------------------------------------------
val minCompileSdk = 36

// 对单个子项目抬升 compileSdk（只升不降）
fun bumpCompileSdk(project: Project) {
    val androidExtension = project.extensions.findByType(BaseExtension::class.java) ?: return
    val currentCompileSdk =
        androidExtension.compileSdkVersion
            ?.removePrefix("android-")
            ?.toIntOrNull()
    if (currentCompileSdk == null || currentCompileSdk < minCompileSdk) {
        project.logger.lifecycle(
            "[work_photos] :${project.name} compileSdkVersion " +
                "${androidExtension.compileSdkVersion} -> $minCompileSdk"
        )
        androidExtension.compileSdkVersion(minCompileSdk)
    }
}

subprojects {
    // 注意：上方第 21 行 `subprojects { evaluationDependsOn(":app") }` 会把 :app 提前评估；
    // 此时再对 :app 调 afterEvaluate 会抛
    //   "Cannot run Project.afterEvaluate(Action) when the project is already evaluated."
    // 因此对「已评估完成」的工程（典型即 :app，其 compileSdk 本就是 36，无需抬升）直接应用；
    // 其余插件子项目此时尚未评估，注册 afterEvaluate：在它们自身 build.gradle 配置完
    // android{ compileSdk=xx } 之后、AGP 生成变体与 checkReleaseAarMetadata 之前抬到 36。
    if (state.executed) {
        bumpCompileSdk(project)
    } else {
        afterEvaluate { bumpCompileSdk(project) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
