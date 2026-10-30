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
    // CameraX 1.6's class files reference CallbackToFutureAdapter; JDK 22+ javac
    // fails ("Cannot attach type annotations") unless it is on the classpath.
    if (project.name == "camera_android_camerax") {
        project.plugins.withId("com.android.library") {
            project.dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
