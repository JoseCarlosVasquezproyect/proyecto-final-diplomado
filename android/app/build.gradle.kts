import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "bo.edu.uajms.proyectofinal360"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "bo.edu.uajms.proyectofinal360"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Un APK de produccion nunca debe quedar firmado con la clave debug.
            // Cuando no exista el keystore, la verificacion al final de este
            // archivo detiene la tarea de release antes de generar el artefacto.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Mantiene disponibles las tareas debug para desarrollo, pero evita por
// completo que assembleRelease/bundleRelease generen un APK no distribuible.
gradle.taskGraph.whenReady { graph ->
    val requestsRelease = graph.allTasks.any { task ->
        task.name.contains("release", ignoreCase = true) &&
            (task.name.contains("assemble", ignoreCase = true) ||
                task.name.contains("bundle", ignoreCase = true) ||
                task.name.contains("package", ignoreCase = true))
    }
    if (requestsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Falta android/key.properties. Cree el keystore y configurelo segun android/key.properties.example antes de generar un release.",
        )
    }
}

kotlin {
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}

flutter { source = "../.." }
