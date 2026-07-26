import com.android.build.gradle.BaseExtension

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

// Plugins with native code (e.g. flutter_pty) declare `ndkVersion = android.ndkVersion`
// inside their own `android` block. That self-reference resolves to the Android Gradle
// Plugin's default NDK rather than the app's `flutter.ndkVersion`, so the plugin asks for
// an NDK the SDK may not have installed. Pin every Android subproject to the app's NDK.
// The `:app` project is excluded: it already sets `ndkVersion` from `flutter.ndkVersion`,
// and it has been evaluated by the `evaluationDependsOn` above, so it can no longer accept
// an `afterEvaluate` callback.
subprojects {
    if (project.path == ":app") return@subprojects
    afterEvaluate {
        val appExtension = project(":app").extensions.findByName("android")
        val subprojectExtension = extensions.findByName("android")
        if (appExtension is BaseExtension && subprojectExtension is BaseExtension) {
            subprojectExtension.ndkVersion = appExtension.ndkVersion
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
