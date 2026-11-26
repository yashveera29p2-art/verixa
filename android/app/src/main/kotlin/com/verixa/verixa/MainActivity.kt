package com.verixa.verixa

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

// A FragmentActivity with a transparent background, as the Truecaller SDK
// needs for its consent sheet and number verification.
class MainActivity : FlutterFragmentActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "verixa/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Anonymous device facts for the install counter (no personal data).
                    "info" -> result.success(
                        mapOf(
                            "id" to anonymousId(),
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "android" to Build.VERSION.RELEASE,
                            "sdk" to Build.VERSION.SDK_INT,
                            // Changes on every (re)install: the Terms and the
                            // guided tour are shown once per installation.
                            "installKey" to "${anonymousId().take(16)}-${firstInstallTime()}",
                        )
                    )
                    // Opens a web page in the phone's browser (Terms, job links).
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null || !(url.startsWith("https://") || url.startsWith("http://") ||
                                url.startsWith("mailto:"))) {
                            result.success(false)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    // Phone permissions Truecaller needs to detect its missed
                    // call. Returns true when all are granted.
                    "phonePermissions" -> {
                        val missing = phonePermissions().filter {
                            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
                        }
                        if (missing.isEmpty()) {
                            result.success(true)
                        } else {
                            permissionResult?.success(false)
                            permissionResult = result
                            requestPermissions(missing.toTypedArray(), PHONE_PERMISSIONS)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun phonePermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            arrayOf(Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_CALL_LOG,
                Manifest.permission.ANSWER_PHONE_CALLS)
        } else {
            arrayOf(Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_CALL_LOG,
                Manifest.permission.CALL_PHONE)
        }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PHONE_PERMISSIONS) {
            permissionResult?.success(
                grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            permissionResult = null
        }
    }

    private fun firstInstallTime(): Long = try {
        packageManager.getPackageInfo(packageName, 0).firstInstallTime
    } catch (e: Exception) {
        0L
    }

    /**
     * A one-way hash of Android's per-app device ID: the same phone always
     * gives the same value (so it's counted once), but it can't be traced
     * back to the phone or the person.
     */
    private fun anonymousId(): String {
        val raw = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("verixa:$raw".toByteArray())
        return digest.joinToString("") { "%02x".format(it) }.take(32)
    }

    private companion object {
        const val PHONE_PERMISSIONS = 4711
    }
}
