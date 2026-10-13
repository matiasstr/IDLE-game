import java.io.File
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
val signingEnvironment = listOf(
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it) }

val releaseKeystore: File? = when {
    signingEnvironment.values.any { !it.isNullOrBlank() } -> {
        val missing = signingEnvironment.filterValues { it.isNullOrBlank() }.keys
        if (missing.isNotEmpty()) {
            throw GradleException("Incomplete Android release signing environment. Missing: ${missing.joinToString()}")
        }
        val directory = System.getenv("RUNNER_TEMP")?.let { File(it, "neural-idle-signing") }
            ?: rootProject.file(".gradle/neural-idle-signing")
        val keystore = File(directory, "release-keystore.jks")
        val bytes = try {
            Base64.getDecoder().decode(
                signingEnvironment.getValue("ANDROID_KEYSTORE_BASE64")!!.replace(Regex("\\s"), ""),
            )
        } catch (_: IllegalArgumentException) {
            throw GradleException("ANDROID_KEYSTORE_BASE64 is not valid base64.")
        }
        directory.mkdirs()
        keystore.writeBytes(bytes)
        signingProperties.setProperty("storePassword", signingEnvironment.getValue("ANDROID_KEYSTORE_PASSWORD"))
        signingProperties.setProperty("keyAlias", signingEnvironment.getValue("ANDROID_KEY_ALIAS"))
        signingProperties.setProperty("keyPassword", signingEnvironment.getValue("ANDROID_KEY_PASSWORD"))
        keystore
    }
    signingPropertiesFile.isFile -> {
        signingPropertiesFile.inputStream().use { signingProperties.load(it) }
        val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .filter { signingProperties.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException("Incomplete android/key.properties. Missing: ${missing.joinToString()}")
        }
        rootProject.file(signingProperties.getProperty("storeFile"))
    }
    else -> null
}

if (releaseKeystore != null && !releaseKeystore.isFile) {
    throw GradleException("Release keystore not found. Check storeFile in android/key.properties.")
}

android {
    namespace = "io.github.matiasstr.neuralidle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.matiasstr.neuralidle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Keep local release-mode runs working without a production key.
            signingConfig = signingConfigs.getByName(if (releaseKeystore == null) "debug" else "release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
