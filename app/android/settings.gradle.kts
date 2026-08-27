pluginManagement {
    val flutterSdkPath: String by lazy {
        val props = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            props.load(localPropertiesFile.inputStream())
        }
        props.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")
            ?: error("Flutter SDK not found. Define flutter.sdk in local.properties or set FLUTTER_ROOT.")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
