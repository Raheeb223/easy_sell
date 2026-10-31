allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // App size: google_mlkit_text_recognition bundles the OCR engine (~12 MB
    // per CPU type). The Play-services build has the same API but uses the
    // engine Google Play services keeps on the phone (fetched once at install,
    // see the DEPENDENCIES meta-data in AndroidManifest.xml). Until it is
    // there, a scan just goes by the photo (LabelReader fails soft).
    configurations.all {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.google.mlkit:text-recognition"))
                .using(module("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1"))
        }
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
    // Plugins such as tflite_flutter pin Java to 11 but leave Kotlin's jvmTarget
    // unset, so Kotlin targets a newer JVM and Gradle rejects the mismatch.
    // Make each Kotlin compile target whatever its Java compile targets.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        val javaName = name.replace("Kotlin", "JavaWithJavac")
        val tasks = project.tasks
        compilerOptions.jvmTarget.set(project.provider {
            (tasks.findByName(javaName) as? JavaCompile)?.targetCompatibility
                ?.let { org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(it) }
        })
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
