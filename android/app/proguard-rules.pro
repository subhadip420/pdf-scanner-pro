# ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }

# BouncyCastle / PDF Encryption rules
-dontwarn org.bouncycastle.**
-keep class org.bouncycastle.** { *; }

# Google Play Core / Split Install
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }

# ---------------------------------------------------------
# FLUTTER PLUGINS, CAMERA & PIGEON (ULTIMATE FIX)
# ---------------------------------------------------------
# Keep Plugin Registrant so plugins actually register
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keepclassmembers class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep all Flutter Plugins and their internal methods safe
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class io.flutter.plugins.** { *; }

# Keep Pigeon completely intact (Crucial for Dart-Native communication)
-keep class dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }

# Keep AndroidX Camera and Guava
-keep class androidx.camera.** { *; }
-keepclassmembers class androidx.camera.** { *; }
-keep class com.google.common.** { *; }
-dontwarn com.google.common.**

# 🚨 MASTER FIX 2: CameraX plugin files ko kisi bhi haalat mein minify hone se roko
-keep class io.flutter.plugins.camera_android_camerax.** { *; }
-keepclassmembers class io.flutter.plugins.camera_android_camerax.** { *; }
-dontwarn io.flutter.plugins.camera_android_camerax.**