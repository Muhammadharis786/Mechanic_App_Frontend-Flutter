package com.example.mech_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PRESENCE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPresenceGuard" -> {
                    startService(Intent(this, MechanicPresenceService::class.java))
                    result.success(null)
                }
                "stopPresenceGuard" -> {
                    stopService(Intent(this, MechanicPresenceService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (isFinishing) {
            MechanicPresenceHelper.markOfflineIfNeeded(applicationContext)
        }
        super.onDestroy()
    }

    companion object {
        private const val PRESENCE_CHANNEL = "com.example.mech_app/mechanic_presence"
    }
}
