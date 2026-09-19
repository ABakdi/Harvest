import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (git-ignored):
//   storeFile=/absolute/path/harvest-upload.jks
//   storePassword=…
//   keyAlias=harvest
//   keyPassword=…
// Without it a release build fails. The first four releases went out
// signed with the debug key, which is a key anyone has — a warning in
// a log I do not read is not a guard ([[Audit-v2]] S3-08). On a dev
// machine, -PallowDebugSigning=true says so out loud and lets
// `flutter run --release` through.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null
val allowDebugSigning = project.findProperty("allowDebugSigning") == "true"

// Checked when the build is about to run rather than while it is being
// configured, so a debug build is not held to a release's rules.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { task ->
        task.name.contains("Release") &&
            (task.name.startsWith("assemble") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("package"))
    }
    if (releasing && !hasReleaseKey && !allowDebugSigning) {
        throw GradleException(
            "No android/key.properties: a release build would be signed " +
                "with the debug key. Add the upload key, or pass " +
                "-PallowDebugSigning=true for a local release run.",
        )
    }
}

android {
    namespace = "com.harvest.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.harvest.app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                logger.warn("key.properties not found: this build is signed with the debug key")
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Steps live in packages/harvest_steps, a plugin, so the 3 AM job's
    // background engine can read them too (checkpoint 8).
}
