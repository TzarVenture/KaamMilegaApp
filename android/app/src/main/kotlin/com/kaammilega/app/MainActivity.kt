package com.kaammilega.app

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Short message tone for chat (the phone's own notification sound,
        // so silent / vibrate mode and the user's chosen tone are respected).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kaammilega.app/sound")
            .setMethodCallHandler { call, result ->
                if (call.method == "playNotification") {
                    try {
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        RingtoneManager.getRingtone(applicationContext, uri)?.play()
                    } catch (_: Exception) {
                        // No tone available: stay silent.
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
