# ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }

# BouncyCastle / PDF Encryption rules
-dontwarn org.bouncycastle.**
-keep class org.bouncycastle.** { *; }

# Google Play Core / Split Install (Naya fix)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# CameraX & Pigeon Plugins (App crash fix)
-keep class androidx.camera.** { *; }
-keep class dev.flutter.pigeon.** { *; }

# CameraX Native Plugin & Guava dependencies (এই লাইনগুলো তুমি ভুলে গেছিলে!)
-keep class io.flutter.plugins.camera.** { *; }
-keep class io.flutter.plugins.camerax.** { *; }
-keep class com.google.common.util.concurrent.ListenableFuture { *; }