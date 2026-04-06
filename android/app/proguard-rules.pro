# Keep ONNX Runtime JNI bindings
-keep class ai.onnxruntime.** { *; }

# Keep Flutter plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress warnings for Play Core deferred components (not used)
-dontwarn com.google.android.play.core.**
