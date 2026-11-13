package com.verixa.verixa

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Anonymous device facts for the install counter (no personal data).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "verixa/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "info") {
                    result.success(
                        mapOf(
                            "id" to anonymousId(),
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "android" to Build.VERSION.RELEASE,
                            "sdk" to Build.VERSION.SDK_INT,
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
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
}
