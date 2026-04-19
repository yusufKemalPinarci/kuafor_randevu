package com.kuaflex.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kuaflex.app/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val securityHelper = SecurityHelper(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSecurityStatus" -> {
                    val status = mapOf(
                        "isRooted" to securityHelper.isRooted(),
                        "isDebuggerAttached" to securityHelper.isDebuggerAttached(),
                        "isEmulator" to securityHelper.isEmulator(),
                        "isHooked" to securityHelper.isHookingFrameworkDetected(),
                        "signingCertHash" to securityHelper.getSigningCertHash(),
                        "installerPackage" to securityHelper.getInstallerPackage(),
                        "isFromTrustedInstaller" to securityHelper.isFromTrustedInstaller(),
                    )
                    result.success(status)
                }
                "isRooted" -> result.success(securityHelper.isRooted())
                "isDebuggerAttached" -> result.success(securityHelper.isDebuggerAttached())
                "isEmulator" -> result.success(securityHelper.isEmulator())
                "isHooked" -> result.success(securityHelper.isHookingFrameworkDetected())
                "getSigningCertHash" -> result.success(securityHelper.getSigningCertHash())
                else -> result.notImplemented()
            }
        }
    }
}
