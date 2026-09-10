plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ba.nasadomena.client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ba.nasadomena.client"
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


    // >>> BEGIN GENERATED FLAVORS
    // GENERISANO — ne editovati ručno. Pokreni: dart run tool/gen_flavors.dart
    // AGP 9 gasi resValues po defaultu; app_name po flavoru
    // se generiše upravo kroz resValue, pa mora biti uključen.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "tenant"

    productFlavors {
        create("barberstudiovitez") {
            dimension = "tenant"
            applicationId = "ba.nasadomena.barberstudiovitez"
            resValue("string", "app_name", "Barber Studio Vitez")
            versionCode = 1
            versionName = "1.0.0"
        }
        create("beautystudiotravnik") {
            dimension = "tenant"
            applicationId = "ba.nasadomena.beautystudiotravnik"
            resValue("string", "app_name", "Beauty Studio Travnik")
            versionCode = 1
            versionName = "1.0.0"
        }
    }
    // <<< END GENERATED FLAVORS

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
