import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStoreFile = System.getenv("ANDROID_KEYSTORE_PATH")
val releaseStorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasReleaseSigning =
    !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

fun dartDefineValue(name: String): String? {
    val encodedDefinitions = project.findProperty("dart-defines")?.toString()
    if (encodedDefinitions.isNullOrBlank()) return null

    return encodedDefinitions.split(",")
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .firstNotNullOfOrNull { definition ->
            val separatorIndex = definition.indexOf("=")
            if (separatorIndex <= 0) {
                null
            } else {
                val key = definition.substring(0, separatorIndex)
                val value = definition.substring(separatorIndex + 1)
                if (key == name) value else null
            }
        }
}

val buildChannel = (
    project.findProperty("UMEKO_BUILD_CHANNEL")?.toString()
        ?: dartDefineValue("UMEKO_BUILD_CHANNEL")
        ?: "release"
).lowercase()
val isDevBuild = buildChannel == "dev"
val appDisplayName = if (isDevBuild) "Umeko IR Dev" else "Umeko IR"
val applicationIdBase = "com.example.umeko_ir_flutter"
val canUseReleaseSigning = hasReleaseSigning && !isDevBuild

android {
    namespace = "com.example.umeko_ir_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = if (isDevBuild) "$applicationIdBase.dev" else applicationIdBase
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = if (isDevBuild) "${flutter.versionName}-dev" else flutter.versionName
        manifestPlaceholders["appLabel"] = appDisplayName
    }

    if (canUseReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (canUseReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
