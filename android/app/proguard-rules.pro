# 📍 android/app/proguard-rules.pro

# TensorFlow Lite 관련 클래스들을 삭제하지 않도록 보호합니다.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# 빌드 과정에서 필요한 Java 모델 관련 클래스들을 보호합니다.
-keep class javax.lang.model.** { *; }
-dontwarn javax.lang.model.**