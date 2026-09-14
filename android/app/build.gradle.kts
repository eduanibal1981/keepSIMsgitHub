import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// `storeFile` is resolved against android/ first and android/app/ second, so a
// key.properties written on one machine keeps working on the other regardless of
// which directory its relative path was written against. Absolute paths are
// returned unchanged by `file()`, so they are unaffected.
val releaseStoreFile: File? =
    keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }?.let { path ->
        listOf(rootProject.file(path), project.file(path)).firstOrNull { it.exists() }
    }

// Why the release key is unusable, or null when it is usable. Nothing is thrown
// here: see the release-artifact guard at the bottom of this file.
val releaseKeystoreProblem: String? =
    if (!keystorePropertiesFile.exists()) {
        "android/key.properties does not exist"
    } else {
        val missing =
            listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
        when {
            missing.isNotEmpty() ->
                "android/key.properties is missing ${missing.joinToString(", ")}"
            releaseStoreFile == null ->
                "the keystore '${keystoreProperties.getProperty("storeFile")}' named in " +
                    "android/key.properties was not found"
            else -> null
        }
    }

val allowDebugSigning = project.findProperty("allowDebugSigning")?.toString() == "true"

extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
    namespace = "com.keep_sims"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.keep_sims"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only created when the key is actually usable, so `findByName("release")`
        // is a reliable "can we sign a shippable build?" test.
        if (releaseKeystoreProblem == null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            when {
                releaseKeystoreProblem == null ->
                    signingConfig = signingConfigs.getByName("release")

                allowDebugSigning -> {
                    logger.warn(
                        "WARNING: signing the release build with the DEBUG key because " +
                            "-PallowDebugSigning=true was set ($releaseKeystoreProblem). " +
                            "This artifact cannot be uploaded to Play.",
                    )
                    signingConfig = signingConfigs.getByName("debug")
                }

                // Otherwise leave the variant unsigned on purpose and let the guard
                // below stop the build with a readable message.
                else -> Unit
            }
        }
    }
}

extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.16.0"))
    implementation("com.google.firebase:firebase-analytics")
}

// Fail the build when a release artifact is requested without a usable upload key
// — but only then.
//
// Throwing at configuration time (the original behaviour) fires while *every*
// task graph is being built, so `flutter build apk` (debug), `flutter run`, IDE
// Gradle sync and even `gradlew tasks` all died on any machine without a
// key.properties, which is every machine here until the upload keystore exists.
//
// Hooking the release packaging tasks keeps all of that working while still making
// it impossible to ship a wrongly-signed build: the release variant is left
// *unsigned* above rather than quietly falling back to the debug key, so even a
// task name that slipped past this list would produce a visibly unsigned artifact
// instead of an installable one signed with a throwaway key.
if (releaseKeystoreProblem != null && !allowDebugSigning) {
    // `preReleaseBuild` runs before the release variant compiles anything, so the
    // failure lands in seconds instead of after a full Kotlin/Dart build; the
    // packaging tasks are listed too so a graph that somehow skips it still stops.
    val releaseArtifactTasks =
        setOf(
            "preReleaseBuild",
            "assembleRelease",
            "bundleRelease",
            "packageRelease",
            "packageReleaseBundle",
        )
    tasks.matching { it.name in releaseArtifactTasks }.configureEach {
        doFirst {
            throw GradleException(
                "RELEASE BUILD FAILED: $releaseKeystoreProblem, so this build has no " +
                    "release signing key.\n" +
                    "For a Play Store release, create android/key.properties with " +
                    "storeFile, storePassword, keyAlias and keyPassword.\n" +
                    "For local testing ONLY, pass -PallowDebugSigning=true " +
                    "(flutter: --android-project-arg=allowDebugSigning=true).",
            )
        }
    }
}
