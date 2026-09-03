# The release build has isMinifyEnabled = true, and build.gradle.kts already
# pointed at this file — it just did not exist yet.
#
# flutter_local_notifications serialises scheduled notifications to disk with
# Gson so it can restore them after a reboot. That path is entirely reflective,
# so R8 strips it and scheduled step reminders fail *silently* in release while
# working perfectly in debug. Keep the plugin and Gson's reflective machinery.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Gson needs generic signatures and annotations intact to rebuild typed objects.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn sun.misc.**

# Fields of serialised model classes are matched by name, so they must not be
# renamed even when the class itself survives.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# TypeToken subclasses carry the generic type at runtime.
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# Suppress warnings for optional desugaring/annotation deps that are not on the
# runtime classpath.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
