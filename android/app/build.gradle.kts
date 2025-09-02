import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Activa Google Services plugin
}

val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        FileInputStream(keystorePropsFile).use { load(it) }
    }
}

android {
    namespace = "com.example.sansebassms"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ Habilita desugaring requerido por flutter_local_notifications
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.sansebassms"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        // ✅ Habilitar multidex
        multiDexEnabled = true
    }

    signingConfigs {
        // Create or update the release signing config
        if (keystorePropsFile.exists()) {
            create("release") {
                val storeFilePath = keystoreProps.getProperty("storeFile") ?: ""
                if (storeFilePath.isNotBlank()) {
                    storeFile = file(storeFilePath)
                }
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Only assign if we actually created the signing config
            if (signingConfigs.names.contains("release")) {
                signingConfig = signingConfigs.getByName("release")
            }
            // keep existing minify/shrink settings; if none exist, don't add new ones
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Añadir multidex
    implementation("androidx.multidex:multidex:2.0.1")

    // ✅ Añadir desugaring JDK libs para compatibilidad con flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
