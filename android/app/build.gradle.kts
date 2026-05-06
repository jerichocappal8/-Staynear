import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// project.findProperty() reads gradle.properties, NOT local.properties.
// Explicitly load local.properties so MAPS_API_KEY is available at build time.
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.example.staynear"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.staynear"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Env var takes priority over local.properties (useful for CI).
        val mapsKey = System.getenv("MAPS_API_KEY")
            ?: localProps.getProperty("MAPS_API_KEY", "")

        if (mapsKey.isEmpty()) {
            println("WARNING ⚠️  MAPS_API_KEY is not set — Android Google Maps will show blank tiles.")
            println("  Add MAPS_API_KEY=<your_key> to android/local.properties")
        } else {
            println("INFO: MAPS_API_KEY loaded (${mapsKey.length} chars).")
        }

        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
