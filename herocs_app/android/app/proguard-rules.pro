# ===================================================================
# HEROCS ProGuard Rules - COMPLETE VERSION
# ===================================================================

# ===================================================================
# 1. ARCore & Sceneform Rules
# ===================================================================
-keep class com.google.ar.core.** { *; }
-keep class com.google.ar.sceneform.** { *; }
-keepclassmembers class com.google.ar.sceneform.** { *; }

# Keep animation classes
-keep class com.google.ar.sceneform.animation.** { *; }

# Keep asset loader classes
-keep class com.google.ar.sceneform.assets.** { *; }

# Keep rendering classes
-keep class com.google.ar.sceneform.rendering.** { *; }

# Keep utilities
-keep class com.google.ar.sceneform.utilities.** { *; }

# ===================================================================
# 2. TensorFlow Lite Rules
# ===================================================================
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }

# TFLite GPU Delegate
-keep class org.tensorflow.lite.gpu.** { *; }
-keepclassmembers class org.tensorflow.lite.gpu.** { *; }

# ===================================================================
# 3. Google Play Core (NEW - FOR APP BUNDLES)
# ===================================================================
-keep class com.google.android.play.core.** { *; }
-keepclassmembers class com.google.android.play.core.** { *; }

# Play Core Split Install
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }

# Play Core Tasks API
-keep class com.google.android.play.core.tasks.** { *; }

# ===================================================================
# 4. Desugar Runtime (Java 8+ support)
# ===================================================================
-keep class com.google.devtools.build.android.desugar.runtime.** { *; }

# Java 8+ stream APIs
-keep class j$.util.** { *; }
-keep class j$.time.** { *; }
-keep class j$.lang.** { *; }

# ===================================================================
# 5. TFLite Support Library
# ===================================================================
-keep class org.tensorflow.lite.support.** { *; }

# ===================================================================
# 6. Camera & Image Processing
# ===================================================================
-keep class androidx.camera.** { *; }

# ===================================================================
# 7. Flutter Rules
# ===================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# ===================================================================
# 8. Suppress Warnings (Prevent build failure on missing classes)
# ===================================================================
-dontwarn com.google.ar.sceneform.**
-dontwarn org.tensorflow.lite.**
-dontwarn j$.util.**
-dontwarn com.google.android.play.core.**

# ===================================================================
# 9. Keep all native methods (JNI)
# ===================================================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ===================================================================
# 10. Keep all annotations
# ===================================================================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
