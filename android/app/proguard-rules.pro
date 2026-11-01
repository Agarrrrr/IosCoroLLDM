# SDKs provide their own consumer rules for reflection, serialization and
# mediation adapters. Keeping entire SDK/plugin packages disables R8 shrinking,
# obfuscation and optimization for most of the DEX.

# JNI lookup depends on native method and declaring class names. Preserve
# descriptor names too; normally referenced plugin code remains optimizable.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Flutter's optional deferred-component integration is not bundled in this app.
-dontwarn com.google.android.play.core.**

# Optional compile-time annotation dependencies do not exist at runtime.
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
