package com.example.mech_app

import android.content.Context
import android.util.Base64
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

object MechanicPresenceHelper {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_EMAIL = "flutter.email"
    private const val KEY_PASSWORD = "flutter.password"
    private const val KEY_USER_TYPE = "flutter.userType"
    private const val KEY_IS_ONLINE = "flutter.mechanic_is_online"
    private const val OFFLINE_URL =
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive"

    fun markOfflineIfNeeded(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val email = prefs.getString(KEY_EMAIL, null) ?: return
        val password = prefs.getString(KEY_PASSWORD, null) ?: return
        val userType = prefs.getString(KEY_USER_TYPE, "MECHANIC") ?: "MECHANIC"
        if (userType != "MECHANIC") return

        val wasOnline = prefs.getBoolean(KEY_IS_ONLINE, false)
        if (!wasOnline) return

        prefs.edit().putBoolean(KEY_IS_ONLINE, false).apply()

        val credentials = "$email;$userType:$password"
        val auth =
            "Basic " +
                Base64.encodeToString(
                    credentials.toByteArray(StandardCharsets.UTF_8),
                    Base64.NO_WRAP,
                )

        Thread {
            var connection: HttpURLConnection? = null
            try {
                connection = (URL(OFFLINE_URL).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 4000
                    readTimeout = 4000
                    doOutput = true
                    setRequestProperty("Authorization", auth)
                    setRequestProperty("Content-Type", "application/json")
                    outputStream.use { stream ->
                        stream.write("""{"isonline":"false"}""".toByteArray())
                    }
                    inputStream.use { stream -> stream.readBytes() }
                }
            } catch (_: Exception) {
                // Best effort before process exit.
            } finally {
                connection?.disconnect()
            }
        }.start()
    }
}
