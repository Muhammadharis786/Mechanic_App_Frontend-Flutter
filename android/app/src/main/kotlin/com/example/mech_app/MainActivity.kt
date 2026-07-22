package com.example.mech_app

import android.content.Intent
import android.os.Build
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
                    val args = call.arguments as? Map<*, *>
                    val mechanicId = when (val raw = args?.get("mechanicId")) {
                        is Number -> raw.toLong()
                        is String -> raw.toLongOrNull() ?: -1L
                        else -> -1L
                    }
                    val authHeader = args?.get("authHeader")?.toString()

                    val intent = Intent(this, MechanicPresenceService::class.java).apply {
                        if (mechanicId > 0) {
                            putExtra(MechanicPresenceService.EXTRA_MECHANIC_ID, mechanicId)
                        }
                        if (!authHeader.isNullOrBlank()) {
                            putExtra(MechanicPresenceService.EXTRA_AUTH_HEADER, authHeader)
                        }
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopPresenceGuard" -> {
                    val stopIntent = Intent(this, MechanicPresenceService::class.java).apply {
                        action = MechanicPresenceService.ACTION_STOP
                    }
                    startService(stopIntent)
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
