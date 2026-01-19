# ARCore keep rules
-keep class com.google.ar.core.** { *; }
-keep class com.google.ar.sceneform.** { *; }
-keep class com.google.devtools.build.android.desugar.runtime.** { *; }

# Sceneform animation classes reported as missing
-dontwarn com.google.ar.sceneform.animation.**
-dontwarn com.google.ar.sceneform.assets.**
-dontwarn com.google.ar.sceneform.rendering.**
-dontwarn com.google.ar.sceneform.utilities.**

# Play Core keep/dontwarn rules (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Generic Flutter R8 rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
