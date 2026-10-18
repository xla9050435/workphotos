pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 国内镜像优先：dl.google.com 在本机直连 10s 超时，会让 :jni 等
        // 子项目在依赖解析阶段直接失败（实测 36 分钟后报 Connection timed out）。
        // 镜像放最前，官方源留作兜底：镜像命中就不必再走外网。
        //
        // 为什么是这三个（curl 逐个验证过，详见报告）：
        //   google        -> 镜像 dl.google.com：androidx.* 与 AGP 插件
        //                    marker（com.android.application:9.1.0 实测 200/0.18s）
        //   public        -> 镜像 repo1.maven.org：Kotlin、第三方库
        //   gradle-plugin -> 镜像 plugins.gradle.org：Gradle 插件 marker
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
