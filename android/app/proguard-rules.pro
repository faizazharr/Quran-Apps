# ─────────────────────────────────────────────────────────────────────────────
# ProGuard / R8 rules for release builds.
#
# Flutter ships its own consumer rules for the engine + plugins, so this file
# only adds project-specific keeps.
# ─────────────────────────────────────────────────────────────────────────────

# Keep generic signatures so reflection-based JSON works (just_audio uses this).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Flutter / Play Core (split-install). Without these, R8 strips classes the
# Flutter embedding looks up reflectively and the release APK crashes on
# startup.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# just_audio uses ExoPlayer underneath.
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# connectivity_plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Strip Log.v / Log.d calls from release binaries (defense-in-depth against
# accidentally leaking debug data to logcat).
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}
