import org.gradle.api.tasks.Exec
import java.util.Locale

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val repoRootDir = file("../../../../")
val androidEmbeddedHostDistDir = repoRootDir.resolve(
    "dist/mobile/android-embedded-host",
)
val androidEmbeddedHostBuildScript = repoRootDir.resolve(
    "scripts/build-android-embedded-host-linux.sh",
)
val shouldAutoBuildAndroidEmbeddedHost =
    System.getProperty("os.name")
        .lowercase(Locale.ROOT)
        .contains("linux") &&
        (System.getenv("VKTP_SKIP_ANDROID_EMBEDDED_HOST_BUILD")
            ?.lowercase(Locale.ROOT) !in setOf("1", "true", "yes"))

val buildAndroidEmbeddedHost =
    if (shouldAutoBuildAndroidEmbeddedHost) {
        tasks.register<Exec>("buildAndroidEmbeddedHost") {
            group = "build"
            description =
                "Stages the packaged Android embedded host before Android builds."
            workingDir = repoRootDir
            commandLine("bash", androidEmbeddedHostBuildScript.absolutePath)
            inputs.file(androidEmbeddedHostBuildScript)
            inputs.file(repoRootDir.resolve("go.mod"))
            inputs.file(repoRootDir.resolve("go.sum"))
            inputs.file(repoRootDir.resolve("version.json"))
            inputs.files(
                fileTree(repoRootDir) {
                    include("cmd/android-mobile-host/**")
                    include("internal/**")
                    include("pkg/**")
                    exclude("dist/**")
                    exclude("build/**")
                },
            )
            outputs.dir(androidEmbeddedHostDistDir)
        }
    } else {
        null
    }

android {
    namespace = "com.defin85.relaydock"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.defin85.relaydock"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir("../../../../dist/mobile/android-embedded-host/jniLibs")
            assets.srcDir("../../../../dist/mobile/android-embedded-host/assets")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.webkit:webkit:1.15.0")
}

buildAndroidEmbeddedHost?.let { task ->
    tasks.named("preBuild") {
        dependsOn(task)
    }
}
