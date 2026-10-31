# google_mlkit_text_recognition references every script's recogniser, but the
# app only bundles the Latin one. R8 must not fail on the scripts that are not
# on the classpath.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit creates its component registrars by reflection; R8 full mode strips
# their no-arg constructors otherwise and text recognition fails to start.
-keep class com.google.mlkit.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# TensorFlow Lite (the on-device vision model) is reached from native code;
# keep it whole so R8 does not strip classes that only JNI uses.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
