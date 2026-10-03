# Google Mobile Ads (AdMob) -- keep-rules for the release build's R8/ProGuard pass.
# Play services AARs usually ship their own consumer rules that AGP auto-merges,
# but this app had zero project-level rules despite isMinifyEnabled=true, so ads
# working in a release build was unverified. Explicit keep rules here remove that
# risk rather than relying solely on the library's bundled consumer rules.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# flutter_local_notifications uses reflection for its receivers/services.
-keep class com.dexterous.** { *; }

# androidx.work (WorkManager, used internally by flutter_local_notifications for
# boot-persistent/scheduled notifications) builds a Room database (WorkDatabase)
# whose implementation class is generated at compile time and instantiated via
# reflection. Without these keep rules R8 strips/renames it and the app crashes
# on EVERY launch with "Failed to create an instance of androidx.work.impl.WorkDatabase"
# -- confirmed via a real-device crash log, this was the actual release-build killer.
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**
