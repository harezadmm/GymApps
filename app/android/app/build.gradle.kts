plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.hariz.gymapps"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Dipakai untuk nama tampilan per build type (resValue di bawah).
    buildFeatures {
        resValues = true
    }

    compileOptions {
        // flutter_local_notifications memakai java.time; desugaring membuatnya
        // jalan di Android lama juga.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.hariz.gymapps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Nama tampilan di launcher (PRD FR-I1). Build debug menimpanya.
        resValue("string", "app_name", "GymApps")
    }

    buildTypes {
        // Build debug terpasang berdampingan dengan build rilis: id dan nama
        // berbeda, jadi menguji di HP atau emulator tidak pernah memaksa
        // menghapus aplikasi rilis beserta datanya karena kunci tanda tangan
        // yang tidak cocok.
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            resValue("string", "app_name", "GymApps Debug")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
