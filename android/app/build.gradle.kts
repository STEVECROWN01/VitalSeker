plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ketermarketing.vitalseker"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.ketermarketing.vitalseker"
        minSdk = 24
        // FIX (audit H-13): bump targetSdk to 35 (Android 15). Google Play
        // requires new apps to target SDK 35 by August 31, 2025, and existing
        // apps by November 1, 2025. After these deadlines, new submissions
        // are rejected.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    // FIX (audit H-12): define a proper release signing config.
    //
    // The previous release build used signingConfigs.getByName("debug"),
    // which signs release APKs with the debug keystore. Anyone with the
    // standard debug keystore (it's public — every Android dev has it)
    // could build and sign an APK that installs as an "update" to
    // VitalSeker on a user's phone. Play Store also rejects debug-signed
    // AABs.
    //
    // The release keystore is loaded from a key.properties file that is
    // NOT checked into the repo. To build a release APK:
    //   1. Generate a keystore:
    //        keytool -genkey -v -keystore vitalseker.jks \
    //          -keyalg RSA -keysize 2048 -validity 10000 -alias vitalseker
    //   2. Create android/key.properties with:
    //        storePassword=...
    //        keyPassword=...
    //        keyAlias=vitalseker
    //        storeFile=../vitalseker.jks
    //   3. Run: flutter build appbundle --release
    //
    // If key.properties is absent (e.g. dev machine without the keystore),
    // we fall back to the debug signing config so local builds still work.
    val keystoreProperties = java.util.Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config if the keystore is configured;
            // otherwise fall back to debug so local dev builds still work.
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }

    // Rename the output APK from "app-release.apk" to "VitalSeker.apk"
    // so it's easy to find when copying to a phone.
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.ApkVariantOutputImpl
            output.outputFileName = "VitalSeker.apk"
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Force-downgrade androidx libraries that pulled in minAgpVersion 8.9.1 requirements
// via transitive dependencies. We pin to versions that work with AGP 8.7.0 to avoid
// needing to download Gradle 8.11.1 (which fails on hosts that can't resolve
// services.gradle.org).
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.activity:activity:1.9.3")
        force("androidx.activity:activity-ktx:1.9.3")
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.navigationevent:navigationevent-android:1.0.1")
    }
}

flutter {
    source = "../.."
}
