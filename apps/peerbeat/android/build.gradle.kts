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

// Some Flutter plugins (e.g. desktop_drop) still declare an old compileSdk (33),
// but current androidx transitive deps require >= 34. Force every Android
// subproject up to the app's compileSdk so the build doesn't fail on them.
// Reflection keeps this AGP-version-agnostic (no AGP types on the root
// buildscript classpath).
fun forceCompileSdk(p: org.gradle.api.Project) {
    val androidExt = p.extensions.findByName("android") ?: return
    for (name in listOf("compileSdkVersion", "setCompileSdkVersion")) {
        try {
            androidExt.javaClass
                .getMethod(name, Int::class.javaPrimitiveType)
                .invoke(androidExt, 36)
            return
        } catch (_: Exception) {
            // try the next method name / give up silently
        }
    }
}
subprojects {
    // `evaluationDependsOn(":app")` above may have already evaluated some
    // subprojects, so afterEvaluate would throw — apply now if so.
    if (state.executed) forceCompileSdk(project) else afterEvaluate { forceCompileSdk(project) }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
