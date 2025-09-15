plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.chicachew"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.chicachew"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // 필요 시 minifyEnabled/proguardFiles 추가
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    packaging {
        // libc++_shared 중복 충돌 회피
        jniLibs {
            pickFirsts += listOf(
                "lib/arm64-v8a/libc++_shared.so",
                "lib/armeabi-v7a/libc++_shared.so"
            )
        }
        resources {
            excludes += "/META-INF/{AL2.1,LGPL2.1}"
            excludes += "META-INF/LICENSE*"
            excludes += "META-INF/DEPENDENCIES"
        }
    }

    // 모델/MP .task 파일 압축 금지
    androidResources {
        noCompress += setOf("tflite", "lite", "bin", "task")
    }
}

dependencies {
    // Kotlin BOM
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:1.9.24"))

    // TensorFlow Lite (필수)
    val tflVersion = "2.16.1"
    implementation("org.tensorflow:tensorflow-lite:$tflVersion")

    // CameraX
    val cameraX = "1.3.1"
    implementation("androidx.camera:camera-core:$cameraX")
    implementation("androidx.camera:camera-camera2:$cameraX")
    implementation("androidx.camera:camera-lifecycle:$cameraX")
    implementation("androidx.camera:camera-view:$cameraX")
    // ML Kit 어댑터는 선택 (사용 안 하면 제거 가능)
    implementation("androidx.camera:camera-mlkit-vision:$cameraX")

    // MediaPipe Tasks Vision (손/얼굴 랜드마커)
    val mpTasks = "0.10.14"
    implementation("com.google.mediapipe:tasks-vision:$mpTasks")

    // 기타
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("com.google.code.gson:gson:2.10.1")
}

flutter {
    source = "../.."
}
