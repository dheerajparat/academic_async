allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
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
    configurations.configureEach {
        resolutionStrategy {
            // home_widget 0.9.0 declares dynamic versions (1.+ / 2.+ / 1.+),
            // which can fail metadata lookup on unstable DNS/proxy setups.
            force(
                "androidx.glance:glance-appwidget:1.1.1",
                "androidx.work:work-runtime-ktx:2.10.2",
                "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1",
            )
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
