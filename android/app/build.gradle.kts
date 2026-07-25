import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.keep_sims"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    
    // FORCE GRADLE TO USE MODERN BUILD TOOLS
    buildToolsVersion = "35.0.0" 

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.keep_sims"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storeFileProp = keystoreProperties.getProperty("storeFile")
                val storePasswordProp = keystoreProperties.getProperty("storePassword")
                val keyAliasProp = keystoreProperties.getProperty("keyAlias")
                val keyPasswordProp = keystoreProperties.getProperty("keyPassword")

                if (storeFileProp != null && storePasswordProp != null && keyAliasProp != null && keyPasswordProp != null) {
                    val sFile = file(storeFileProp)
                    if (sFile.exists()) {
                        storeFile = sFile
                        storePassword = storePasswordProp
                        keyAlias = keyAliasProp
                        keyPassword = keyPasswordProp
                    } else {
                        throw GradleException("Release keystore file '$storeFileProp' specified in key.properties does not exist.")
                    }
                } else {
                    throw GradleException("key.properties is incomplete or missing required properties.")
                }
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists() && signingConfigs.findByName("release") != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
  implementation(platform("com.google.firebase:firebase-bom:34.16.0"))
  implementation("com.google.firebase:firebase-analytics")
}