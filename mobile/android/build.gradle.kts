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

subprojects {
    val configureSdk: Project.() -> Unit = {
        if (hasProperty("android")) {
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val method = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    method.invoke(android, 36)
                } catch (_: Throwable) {
                    try {
                        val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        method.invoke(android, 36)
                    } catch (_: Throwable) {
                        try {
                            val method = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                            method.invoke(android, 36)
                        } catch (_: Throwable) {}
                    }
                }
            }
        }
    }

    if (state.executed) {
        configureSdk()
    } else {
        afterEvaluate { configureSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
