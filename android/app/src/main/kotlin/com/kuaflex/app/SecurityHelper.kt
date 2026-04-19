package com.kuaflex.app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import java.io.File
import java.net.Socket
import java.security.MessageDigest

/**
 * Native güvenlik kontrolleri — MethodChannel üzerinden Flutter'a iletilir.
 *
 * Kontroller:
 *  • Root tespiti (su binary, yönetici uygulamaları, test-keys)
 *  • Debugger tespiti
 *  • Emulator tespiti
 *  • Frida / Xposed hooking tespiti
 *  • APK imza doğrulaması
 *  • Yükleyici (installer) doğrulaması
 */
class SecurityHelper(private val context: Context) {

    // ═══════════════════════════════════════════════════════════════════════
    // Root Tespiti
    // ═══════════════════════════════════════════════════════════════════════

    fun isRooted(): Boolean =
        checkRootBinaries() || checkRootManagementApps() || checkTestKeys()

    private fun checkRootBinaries(): Boolean {
        val paths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/data/local/su", "/data/local/bin/su", "/data/local/xbin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/vendor/bin/su", "/su/bin/su"
        )
        return paths.any { File(it).exists() }
    }

    private fun checkRootManagementApps(): Boolean {
        val packages = arrayOf(
            "com.topjohnwu.magisk",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.noshufou.android.su",
            "com.thirdparty.superuser",
            "com.yellowes.su"
        )
        val pm = context.packageManager
        return packages.any {
            try {
                pm.getPackageInfo(it, 0); true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun checkTestKeys(): Boolean =
        Build.TAGS?.contains("test-keys") == true

    // ═══════════════════════════════════════════════════════════════════════
    // Debugger Tespiti
    // ═══════════════════════════════════════════════════════════════════════

    fun isDebuggerAttached(): Boolean =
        Debug.isDebuggerConnected() || Debug.waitingForDebugger()

    // ═══════════════════════════════════════════════════════════════════════
    // Emulator Tespiti
    // ═══════════════════════════════════════════════════════════════════════

    fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("vbox")
                || Build.PRODUCT.contains("emulator")
                || Build.BOARD.lowercase().contains("nox")

    // ═══════════════════════════════════════════════════════════════════════
    // Frida / Xposed Hooking Tespiti
    // ═══════════════════════════════════════════════════════════════════════

    fun isHookingFrameworkDetected(): Boolean =
        checkFridaServer() || checkFridaLibraries() || checkXposedFramework()

    private fun checkFridaServer(): Boolean {
        return try {
            Socket("127.0.0.1", 27042).use { true }
        } catch (_: Exception) {
            false
        }
    }

    private fun checkFridaLibraries(): Boolean {
        return try {
            val maps = File("/proc/self/maps").readText()
            maps.contains("frida") || maps.contains("gadget")
        } catch (_: Exception) {
            false
        }
    }

    private fun checkXposedFramework(): Boolean {
        return try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            true
        } catch (_: ClassNotFoundException) {
            false
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // APK İmza Doğrulaması
    // ═══════════════════════════════════════════════════════════════════════

    fun getSigningCertHash(): String {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES
                )
            }

            val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners?.firstOrNull()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures?.firstOrNull()
            }

            if (signature != null) {
                val md = MessageDigest.getInstance("SHA-256")
                val hash = md.digest(signature.toByteArray())
                hash.joinToString("") { "%02x".format(it) }
            } else ""
        } catch (_: Exception) {
            ""
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Yükleyici (Installer) Doğrulaması
    // ═══════════════════════════════════════════════════════════════════════

    fun getInstallerPackage(): String {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.packageManager
                    .getInstallSourceInfo(context.packageName)
                    .installingPackageName ?: "unknown"
            } else {
                @Suppress("DEPRECATION")
                context.packageManager
                    .getInstallerPackageName(context.packageName) ?: "unknown"
            }
        } catch (_: Exception) {
            "unknown"
        }
    }

    fun isFromTrustedInstaller(): Boolean {
        val installer = getInstallerPackage()
        val trusted = setOf(
            "com.android.vending",              // Google Play Store
            "com.sec.android.app.samsungapps",   // Samsung Galaxy Store
            "com.huawei.appmarket",              // Huawei AppGallery
        )
        return trusted.contains(installer)
    }
}
