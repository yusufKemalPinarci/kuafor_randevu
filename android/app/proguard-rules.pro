# ═══════════════════════════════════════════════════════════════════════════
# KuaFlex ProGuard/R8 Kuralları — Anti-Reverse Engineering
# ═══════════════════════════════════════════════════════════════════════════

# ─── Agresif Obfuscation ─────────────────────────────────────────────────
-repackageclasses ''
-allowaccessmodification
-optimizationpasses 5

# ─── Flutter (sadece engine + plugin arayüzü) ────────────────────────────
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# ─── Firebase ─────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Google Play Billing ──────────────────────────────────────────────────
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }

# ─── Google Play Integrity ────────────────────────────────────────────────
-keep class com.google.android.play.core.integrity.** { *; }

# ─── KuaFlex Security (MethodChannel reflection) ─────────────────────────
-keep class com.kuaflex.app.SecurityHelper { *; }

# ─── Kotlin / OkHttp ─────────────────────────────────────────────────────
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── JSON Serializasyon ──────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# ─── Crash Reporting ─────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ─── Android Log Çağrılarını Release'den Kaldır ──────────────────────────
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
