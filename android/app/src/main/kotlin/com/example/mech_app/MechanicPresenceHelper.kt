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
    private const val KEY_USER_ID = "flutter.userId"
    private const val KEY_MECH_NUMERIC_ID = "flutter.cached_mech_numeric_id"
    private const val OFFLINE_URL =
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive"

    fun persistOnlineFlag(context: Context, online: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_IS_ONLINE, online)
            .apply()
    }

    fun readMechanicId(context: Context): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val fromCache = prefs.getLong(KEY_MECH_NUMERIC_ID, -1L)
        if (fromCache > 0) return fromCache

        // SharedPreferences may store ints from Flutter setInt
        val asInt = try {
            prefs.getInt(KEY_MECH_NUMERIC_ID, -1)
        } catch (_: ClassCastException) {
            -1
        }
        if (asInt > 0) return asInt.toLong()

        val userIdLong = prefs.getLong(KEY_USER_ID, -1L)
        if (userIdLong > 0) return userIdLong

        val userIdInt = try {
            prefs.getInt(KEY_USER_ID, -1)
        } catch (_: ClassCastException) {
            -1
        }
        return if (userIdInt > 0) userIdInt.toLong() else -1L
    }

    fun readAuthHeader(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val email = prefs.getString(KEY_EMAIL, null) ?: return null
        val password = prefs.getString(KEY_PASSWORD, null) ?: return null
        val userType = prefs.getString(KEY_USER_TYPE, "MECHANIC") ?: "MECHANIC"
        if (userType != "MECHANIC") return null

        val credentials = "$email;$userType:$password"
        return "Basic " +
            Base64.encodeToString(
                credentials.toByteArray(StandardCharsets.UTF_8),
                Base64.NO_WRAP,
            )
    }

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
