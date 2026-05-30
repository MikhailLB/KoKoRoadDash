import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ---- Signing: read from android/key.properties (not committed to git) ----
val keystoreFile = rootProject.file("key.properties")

fun prop(key: String): String {
    if (!keystoreFile.exists()) return ""
    val p = Properties()
    p.load(keystoreFile.reader())
    return p.getProperty(key, "")
}

android {
    namespace = "com.kokogames.kokoroaddash"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    signingConfigs {
        create("release") {
            if (keystoreFile.exists()) {
                storeFile     = rootProject.file(prop("storeFile"))
                storePassword = prop("storePassword")
                keyAlias      = prop("keyAlias")
                keyPassword   = prop("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.kokogames.kokoroaddash"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystoreFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled    = false
            isShrinkResources  = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
