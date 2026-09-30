import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dibaca dari android/key.properties (gitignored; cara membuatnya
// ada di docs/RELEASE.md). Tanpa berkas itu build rilis tetap jalan dengan
// debug key — supaya `flutter run --release` dan CI tanpa rahasia tidak
// gagal — tapi APK-nya tidak bisa memperbarui APK yang ditandatangani kunci
// asli, dan sebaliknya. Karena itu ada peringatan di bawah: jangan sampai
// APK debug-key terbagikan tanpa disadari.
val keyPropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keyPropertiesFile.exists()
val keyProperties = Properties().apply {
    if (hasReleaseKey) keyPropertiesFile.inputStream().use { load(it) }
}

fun releaseKey(name: String): String =
    keyProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: error("key.properties: '$name' kosong, lihat docs/RELEASE.md")

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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                val storePath = releaseKey("storeFile")
                // Path relatif dihitung dari folder key.properties (android/),
                // bukan dari android/app/ — tempat orang menaruh berkasnya
                // adalah tempat ia menulis path-nya.
                storeFile = File(storePath).let { if (it.isAbsolute) it else File(keyPropertiesFile.parentFile, storePath) }
                storePassword = releaseKey("storePassword")
                keyAlias = releaseKey("keyAlias")
                keyPassword = releaseKey("keyPassword")
            }
        }
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
            // Kunci asli kalau key.properties ada; debug key kalau tidak
            // (lihat komentar di atas dan peringatan di bawah).
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

if (!hasReleaseKey) {
    // Hanya saat memang ada tugas rilis di antrean: build debug tidak perlu
    // diganggu peringatan tentang APK rilis.
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.contains("Release") }) {
            logger.warn("PERINGATAN: APK rilis ditandatangani debug key, lihat docs/RELEASE.md")
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
