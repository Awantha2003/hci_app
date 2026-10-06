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
// Build every module (including plugins with native code, e.g. `jni`) with
// an NDK and build-tools that are already installed, instead of the default
// NDK 28.2 (~700 MB download) and build-tools 36.0.0. Remove this block once
// those versions are installed.
val localNdkVersion = "27.0.12077973"
val localBuildToolsVersion = "36.1.0"
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            ndkVersion = localNdkVersion
            buildToolsVersion = localBuildToolsVersion
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
