plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.5.0" apply false
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val rootDrive = rootProject.projectDir.path.substringBefore(":")
    val subDrive = project.projectDir.path.substringBefore(":")
    if (rootDrive.equals(subDrive, ignoreCase = true)) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

// file_picker 11 skips the legacy Kotlin plugin on AGP 9. Enable built-in
// Kotlin for this module while older Flutter plugins still require the global
// android.builtInKotlin=false compatibility setting.
project(":file_picker") {
    pluginManager.withPlugin("com.android.library") {
        pluginManager.apply("com.android.built-in-kotlin")
    }
}

// Raise the Kotlin language floor for plugin modules we do not own.
//
// `sentry_flutter` (8.14.2) hardcodes `languageVersion = "1.6"` in its own
// `android/build.gradle`. Kotlin 2.2 and later refuse this setting outright:
// "Language version 1.6 is no longer supported". That fails
// `:sentry_flutter:compileDebugKotlin` and with it *every* Android build, debug
// and release alike, in a module this repo cannot edit.
//
// Two properties of this bump are deliberate and load-bearing:
//
//  1. It runs inside `afterEvaluate`, so the `configureEach` hook is registered
//     *after* the plugin's own `kotlinOptions { languageVersion = "1.6" }` has
//     been copied onto its compile tasks. Registering during root evaluation
//     loses that race on some plugins and the 1.6 pin survives untouched.
//
//  2. It only ever raises — a module already at or above the floor keeps its own
//     setting. Force-setting every subproject to an exact version instead would
//     drag `:app` and any Kotlin-2.x plugin *backwards* onto a language version
//     that Kotlin already reports as deprecated, turning a fix for one stale
//     plugin into a slow build break for every up-to-date one.
//
// The floor is 1.9 rather than 1.8 because Kotlin 2.2 already warns that 1.8 is
// deprecated; 1.9 is the oldest language version it still accepts cleanly.
//
// This block MUST stay above the `evaluationDependsOn(":app")` block below. That
// call evaluates `:app` on the spot, and registering `afterEvaluate` on a project
// that has already been evaluated is a hard Gradle error:
// "Cannot run Project.afterEvaluate(Action) when the project is already evaluated."
subprojects {
    afterEvaluate {
        // AGP 9 checks library-to-library compile SDK compatibility. Sentry 8
        // pins API 34, but its package_info_plus dependency requires API 36.
        if (name == "sentry_flutter") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = maxOf(compileSdk ?: 0, 36)
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            val floor = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9
            compilerOptions {
                if (languageVersion.orNull?.let { it < floor } == true) {
                    languageVersion.set(floor)
                }
                if (apiVersion.orNull?.let { it < floor } == true) {
                    apiVersion.set(floor)
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
