import java.util.Properties

// Loaded before the android block so the signing config can ask whether an
// upload key exists at all.
val uploadProperties = Properties()
val uploadKeystore: File? = rootProject.file("key.properties")
    .takeIf { it.exists() }
    ?.also { uploadProperties.load(it.inputStream()) }

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.anthonyessaye.opentv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anthonyessaye.opentv"
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
        // The upload key, when there is one.
        //
        // Read from android/key.properties, which is gitignored and must
        // never be otherwise: it names a keystore and carries its passwords.
        // Absent — which is the normal state for anyone who has just cloned
        // this — the block simply does not exist and release builds fall back
        // to the debug key below, so `flutter run --release` still works.
        if (uploadKeystore != null) {
            create("upload") {
                // Trimmed, every one of them. A properties file keeps
                // whatever whitespace follows a value, an editor shows none
                // of it, and a single trailing space on the path produces
                // "keystore file not found" naming a path that looks exactly
                // right. A password with one is worse: it fails as a wrong
                // password.
                storeFile = file(uploadProperties.getProperty("storeFile").trim())
                storePassword = uploadProperties.getProperty("storePassword").trim()
                keyAlias = uploadProperties.getProperty("keyAlias").trim()
                keyPassword = uploadProperties.getProperty("keyPassword").trim()
            }
        }
    }

    buildTypes {
        release {
            // A debug-signed release is not a mistake to leave silent: Google
            // Play refuses the upload outright, and the failure arrives after
            // a build, an upload and a wait rather than here.
            signingConfig = if (uploadKeystore != null) {
                signingConfigs.getByName("upload")
            } else {
                logger.warn(
                    "OpenTV: no android/key.properties — signing this release " +
                        "with the debug key. The result cannot be uploaded to " +
                        "Google Play. See README."
                )
                signingConfigs.getByName("debug")
            }
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
    // Media3 is the Android engine. Unlike AVPlayer it demuxes MPEG-TS and
    // Matroska natively, which between them are the great majority of a real
    // IPTV catalogue — so Android needs no third-party player at all, and the
    // libVLC dependency stays an Apple-only concern.
    val media3 = "1.4.1"
    implementation("androidx.media3:media3-exoplayer:$media3")
    implementation("androidx.media3:media3-exoplayer-hls:$media3")
    implementation("androidx.media3:media3-exoplayer-dash:$media3")
    implementation("androidx.media3:media3-ui:$media3")

    // Encrypted preferences for the provider password, with the key held in
    // the hardware-backed Android keystore. Xtream embeds credentials in
    // every stream URL, so the app must keep the password to play anything —
    // which makes where it is kept a decision worth making properly.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // The tunnel. Apache-2.0, from WireGuard themselves, carrying the audited
    // Go implementation for all four ABIs and declaring its own VpnService.
    // The alternative — an OpenVPN client — is GPL-2.0 or AGPL-3.0 in every
    // usable form, which would decide this project's licence for it and shut
    // the App Store out entirely.
    implementation("com.wireguard.android:tunnel:1.0.20260102")
}
