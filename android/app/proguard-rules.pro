# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep all native JNI methods (CRITICAL for Pdfrx, FluidSynth / flutter_midi_pro, flutter_lame, Verovio)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable and Serializable implementations
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Google Mobile Ads (AdMob) & Mediation
-keep public class com.google.android.gms.ads.** { *; }
-keep public class com.google.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
-keep class com.vungle.ads.** { *; }
-keep class com.vungle.mediation.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.vungle.**

# RevenueCat (Purchases)
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# AudioPlayers
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# Flutter MIDI Pro / Native Audio
-keep class com.appleeducate.flutter_midi_pro.** { *; }
-dontwarn com.appleeducate.flutter_midi_pro.**

# Pdfrx
-keep class com.mypdfrx.** { *; }
-dontwarn com.mypdfrx.**

# Flutter Lame
-keep class com.example.flutter_lame.** { *; }
-dontwarn com.example.flutter_lame.**

# Verovio Flutter
-keep class com.csa8820.verovio_flutter.** { *; }
-dontwarn com.csa8820.verovio_flutter.**

# Plus Plugins (Wakelock, Share, PackageInfo)
-keep class dev.fluttercommunity.plus.** { *; }

# Google Play Core / Deferred Components
-dontwarn com.google.android.play.core.**

# General suppressions for harmless missing optional compile-time dependencies in third-party libraries
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn androidx.annotation.**
