# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.

# Keep Moshi adapters
-keepclassmembers class * {
    @com.squareup.moshi.FromJson <methods>;
    @com.squareup.moshi.ToJson <methods>;
}

# Keep Retrofit interfaces
-keepattributes Signature
-keepattributes Exceptions

# Keep Room entities
-keep class com.whispermate.aidictation.data.local.entity.** { *; }

# Keep domain models
-keep class com.whispermate.aidictation.domain.model.** { *; }
