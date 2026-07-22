package com.example.mech_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Keeps mechanic "online" while the app is backgrounded by:
 * 1) Running as a foreground service (persistent notification)
 * 2) Sending STOMP heartbeats to /app/heartbeat over WebSocket
 */
class MechanicPresenceService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private var webSocket: WebSocket? = null
    private val stompConnected = AtomicBoolean(false)
    private var mechanicId: Long = -1L
    private var authHeader: String? = null

    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            sendHeartbeatFrame()
            handler.postDelayed(this, HEARTBEAT_INTERVAL_MS)
        }
    }

    private val reconnectRunnable = Runnable {
        if (mechanicId > 0 && !stompConnected.get()) {
            connectStomp()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafely()
                return START_NOT_STICKY
            }
        }

        mechanicId = intent?.getLongExtra(EXTRA_MECHANIC_ID, -1L)
            ?.takeIf { it > 0 }
            ?: MechanicPresenceHelper.readMechanicId(applicationContext)

        authHeader = intent?.getStringExtra(EXTRA_AUTH_HEADER)
            ?: MechanicPresenceHelper.readAuthHeader(applicationContext)

        if (mechanicId <= 0 || authHeader.isNullOrBlank()) {
            Log.w(TAG, "Missing mechanicId/auth — cannot keep presence")
            stopSelf()
            return START_NOT_STICKY
        }

        MechanicPresenceHelper.persistOnlineFlag(applicationContext, true)
        startAsForeground()
        connectStomp()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(heartbeatRunnable)
        handler.removeCallbacks(reconnectRunnable)
        closeSocket()
        MechanicPresenceHelper.markOfflineIfNeeded(applicationContext)
        super.onDestroy()
    }

    private fun startAsForeground() {
        ensureChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Mechanic Online",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps you visible to nearby customers"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = Intent(this, MechanicPresenceService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("You are online")
            .setContentText("Receiving nearby service requests")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .addAction(0, "Go offline", stopPending)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun connectStomp() {
        closeSocket()
        stompConnected.set(false)

        val auth = authHeader ?: return
        val request = Request.Builder()
            .url(WS_URL)
            .header("Authorization", auth)
            .header("Content-Type", "application/json")
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                val connectFrame = buildString {
                    append("CONNECT\n")
                    append("accept-version:1.1,1.2\n")
                    append("heart-beat:10000,10000\n")
                    append("Authorization:$auth\n")
                    append("\n")
                    append(NULL)
                }
                webSocket.send(connectFrame)
                Log.d(TAG, "WS open — STOMP CONNECT sent")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                if (text.startsWith("CONNECTED")) {
                    if (stompConnected.compareAndSet(false, true)) {
                        Log.d(TAG, "STOMP connected — starting native heartbeat")
                        handler.removeCallbacks(heartbeatRunnable)
                        handler.post(heartbeatRunnable)
                    }
                } else if (text.startsWith("ERROR")) {
                    Log.e(TAG, "STOMP ERROR: $text")
                    scheduleReconnect()
                }
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                onMessage(webSocket, bytes.utf8())
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                stompConnected.set(false)
                handler.removeCallbacks(heartbeatRunnable)
                scheduleReconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WS failure: ${t.message}")
                stompConnected.set(false)
                handler.removeCallbacks(heartbeatRunnable)
                scheduleReconnect()
            }
        })
    }

    private fun sendHeartbeatFrame() {
        val socket = webSocket
        if (socket == null || !stompConnected.get() || mechanicId <= 0) {
            scheduleReconnect()
            return
        }

        val body = """{"mechanicId":$mechanicId}"""
        val frame = buildString {
            append("SEND\n")
            append("destination:/app/heartbeat\n")
            append("content-type:application/json\n")
            append("content-length:${body.toByteArray(Charsets.UTF_8).size}\n")
            append("\n")
            append(body)
            append(NULL)
        }

        val ok = socket.send(frame)
        if (ok) {
            Log.d(TAG, "Native heartbeat sent for mechanicId=$mechanicId")
        } else {
            Log.w(TAG, "Failed to send heartbeat — reconnecting")
            scheduleReconnect()
        }
    }

    private fun scheduleReconnect() {
        handler.removeCallbacks(reconnectRunnable)
        handler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
    }

    private fun closeSocket() {
        try {
            webSocket?.close(1000, "stop")
        } catch (_: Exception) {
        }
        webSocket = null
        stompConnected.set(false)
    }

    private fun stopSelfSafely() {
        handler.removeCallbacks(heartbeatRunnable)
        handler.removeCallbacks(reconnectRunnable)
        closeSocket()
        MechanicPresenceHelper.markOfflineIfNeeded(applicationContext)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        private const val TAG = "MechanicPresence"
        private const val CHANNEL_ID = "mechanic_online_channel"
        private const val NOTIFICATION_ID = 4401
        private const val HEARTBEAT_INTERVAL_MS = 10_000L
        private const val RECONNECT_DELAY_MS = 5_000L
        private const val NULL = "\u0000"
        private const val WS_URL =
            "wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket"

        const val ACTION_STOP = "com.example.mech_app.ACTION_STOP_PRESENCE"
        const val EXTRA_MECHANIC_ID = "mechanicId"
        const val EXTRA_AUTH_HEADER = "authHeader"
    }
}
