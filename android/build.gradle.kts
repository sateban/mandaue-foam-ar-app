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
    val project = this
    val applyNamespaceFix = {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val currentNamespace = getNamespace.invoke(android)
                    if (currentNamespace == null) {
                        val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                        
                        var packageName = ""
                        val manifestFile = project.file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            val manifestContent = manifestFile.readText()
                            val match = Regex("package=\"([^\"]+)\"").find(manifestContent)
                            if (match != null) {
                                packageName = match.groupValues[1]
                            }
                        }
                        
                        if (packageName.isEmpty()) {
                            packageName = if (project.name == "ar_flutter_plugin") "com.carius.ar_flutter_plugin" 
                                         else "com.example.${project.name.replace("-", "_")}"
                        }
                        
                        setNamespace.invoke(android, packageName)
                    }
                } catch (e: Exception) {}

                // Force JVM target compatibility and compileSdk
                try {
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    val setSourceCompatibility = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                    val setTargetCompatibility = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                    setSourceCompatibility.invoke(compileOptions, JavaVersion.VERSION_11)
                    setTargetCompatibility.invoke(compileOptions, JavaVersion.VERSION_11)

                    // Try to set compileSdk (int)
                    try {
                        val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                        setCompileSdk.invoke(android, 36)
                    } catch (e: Exception) {
                        // Fallback to older compileSdkVersion (String or int)
                        try {
                            val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                            setCompileSdkVersion.invoke(android, 36)
                        } catch (e2: Exception) {}
                    }
                } catch (e: Exception) {}
            }
        }
        
        // Force Kotlin JVM target
        project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            kotlinOptions {
                jvmTarget = "11"
            }
        }
    }

    if (project.state.executed) {
        applyNamespaceFix()
    } else {
        project.afterEvaluate { applyNamespaceFix() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
