import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ─── Release signing ─────────────────────────────────────────────────────────
// Reads credentials from android/key.properties so they never enter git.
// See android/key.properties.example for the expected schema.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Google's public sample AdMob app ID (always safe to ship in dev builds).
val ADMOB_TEST_APP_ID = "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.labs.quran"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.labs.quran"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AdMob app ID: Google's public TEST ID by default. Only release
        // builds may override it (see buildTypes) so dev/debug builds can
        // never serve real ads (invalid-traffic risk for the AdMob account).
        manifestPlaceholders["admobAppId"] = ADMOB_TEST_APP_ID
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                // Keystore is PKCS12; AGP infers JKS from the .jks extension
                // which causes "Tag number over 30 is not supported" on signing.
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        // ─── DEBUG ───────────────────────────────────────────────────────────
        // Suffixed application id + version name so debug builds can be
        // installed side-by-side with a release build on the same device.
        getByName("debug") {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = true
        }

        // ─── RELEASE ─────────────────────────────────────────────────────────
        // Uses the upload keystore when key.properties is present; otherwise
        // falls back to the debug signing config so `flutter run --release`
        // still works on a clean machine.
        getByName("release") {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            // Real AdMob app ID comes from CI secret / env (ADMOB_APP_ID) or
            // -PADMOB_APP_ID; missing means test ID.
            manifestPlaceholders["admobAppId"] =
                (System.getenv("ADMOB_APP_ID")
                    ?: project.findProperty("ADMOB_APP_ID") as String?)
                    ?.takeIf { it.isNotBlank() }
                    ?: ADMOB_TEST_APP_ID
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
