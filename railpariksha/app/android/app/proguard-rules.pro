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
