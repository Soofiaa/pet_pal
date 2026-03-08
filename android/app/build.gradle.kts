import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.Sofia_Menzel.PetPal.pet_pal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions { jvmTarget = "1.8" }

    defaultConfig {
        applicationId = "com.Sofia_Menzel.PetPal.pet_pal"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Carga key.properties (en la raíz: android/key.properties normalmente)
    val props = Properties()
    val propsFile = rootProject.file("key.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { props.load(it) }
    }

    signingConfigs {
        // Solo crea "release" si hay storeFile válido
        val storeFilePath = props.getProperty("storeFile")
        if (!storeFilePath.isNullOrBlank()) {
            create("release") {
                storeFile = file(storeFilePath)
                storePassword = props.getProperty("storePassword") ?: ""
                keyAlias = props.getProperty("keyAlias") ?: ""
                keyPassword = props.getProperty("keyPassword") ?: ""
            }
        }
    }

    buildTypes {
        debug {
            // No tocar signingConfig: usa debug.keystore por defecto
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true

            // Asigna signingConfig solo si existe
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }
}

flutter { source = "../.." }

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
