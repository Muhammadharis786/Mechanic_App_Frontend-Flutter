package com.example.mech_app

import android.app.Service
import android.content.Intent
import android.os.IBinder

class MechanicPresenceService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        MechanicPresenceHelper.markOfflineIfNeeded(applicationContext)
        super.onDestroy()
    }
}
