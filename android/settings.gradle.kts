pluginManagement {
    val flutterSdkPath = System.getenv("FLUTTER_ROOT")
        ?: run {
            val props = java.util.Properties()
            file("local.properties").takeIf { it.exists() }
                ?.inputStream()?.use { props.load(it) }
            props.getProperty("flutter.sdk")
                ?: error("Flutter SDK not found")
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
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.1" apply false
}

include(":app")
