package com.ubicacion.app

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.content.SharedPreferences
import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.database.FirebaseDatabase
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationRequest
import kotlinx.coroutines.*

class LocationService : Service() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var fusedLocationClient: FusedLocationProviderClient? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(1, buildNotification())
        
        scope.launch {
            startLocationTracking()
        }
        
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "location_channel",
                "Ubicación",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification() = NotificationCompat.Builder(this, "location_channel")
        .setContentTitle("Compartiendo ubicación")
        .setContentText("Enviando ubicación en vivo...")
        .setSmallIcon(android.R.drawable.ic_dialog_map)
        .build()

    private suspend fun startLocationTracking() {
        try {
            FirebaseApp.initializeApp(this)
            val prefs: SharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val clave = prefs.getString("flutter.clave", "") ?: ""
            
            if (clave.isEmpty()) {
                stopSelf()
                return
            }

            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            val locationRequest = LocationRequest.create().apply {
                interval = 5000
                fastestInterval = 2000
                priority = LocationRequest.PRIORITY_HIGH_ACCURACY
            }

            fusedLocationClient?.requestLocationUpdates(
                locationRequest,
                { location ->
                    scope.launch(Dispatchers.IO) {
                        try {
                            FirebaseDatabase.getInstance().reference
                                .child("rooms").child(clave)
                                .setValue(mapOf(
                                    "lat" to location.latitude,
                                    "lng" to location.longitude
                                ))
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                },
                null
            )
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
