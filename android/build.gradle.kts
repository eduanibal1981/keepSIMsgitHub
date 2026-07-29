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
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Raise the Kotlin language floor for plugin modules we do not own.
//
// `sentry_flutter` (8.14.2) hardcodes `languageVersion = "1.6"` in its own
// `android/build.gradle`. Kotlin 2.2 — the version pinned in settings.gradle.kts
// — refuses outright: "Language version 1.6 is no longer supported". That fails
// `:sentry_flutter:compileDebugKotlin` and with it *every* Android build,
// debug and release alike, in a module this repo cannot edit.
//
// Bumping the floor here is the smallest fix that does not fork the plugin or
// pin the whole project back to an old Kotlin. Only versions *below* 1.8 are
// touched, so a plugin that has already moved on keeps its own setting.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val floor = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
