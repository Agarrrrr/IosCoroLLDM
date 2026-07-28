allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExtension = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExtension != null && androidExtension.namespace == null) {
            androidExtension.namespace = "com.example.${name.replace("-", "_").replace(" ", "_")}"
        }
        androidExtension?.defaultConfig?.externalNativeBuild?.cmake?.arguments?.add(
            "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
