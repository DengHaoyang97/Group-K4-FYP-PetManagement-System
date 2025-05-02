# 保留 TensorFlow Lite 的类和方法
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# 保留 TensorFlow Lite GPU Delegate 的类和方法
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# 保留 TensorFlow Lite Acceleration 类
-keep class org.tensorflow.lite.acceleration.** { *; }
-dontwarn org.tensorflow.lite.acceleration.**

# 保留所有 JNI 方法
-keepclasseswithmembers class * {
    native <methods>;
}

# 保留 Flutter Framework 的类
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
