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
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationRequest
import kotlinx.coroutines.*
import android.Manifest
import androidx.core.content.ContextCompat

class LocationService : Service() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(999, buildNotification())
        
        scope.launch {
            startLocationTracking()
        }
        
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "location_channel",
                "Ubicación en tiempo real",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Compartiendo ubicación automática"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification() = NotificationCompat.Builder(this, "location_channel")
        .setContentTitle("🔴 Compartiendo ubicación EN VIVO")
        .setContentText("Actualizando ubicación continuamente...")
        .setSmallIcon(android.R.drawable.ic_dialog_map)
        .setOngoing(true)
        .build()

    private suspend fun startLocationTracking() {
        try {
            try {
                FirebaseApp.initializeApp(this)
            } catch (e: Exception) {
                // Ya está inicializado
            }

            val prefs: SharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val clave = prefs.getString("flutter.clave", "") ?: ""
            val autoOn = prefs.getBoolean("flutter.auto_enabled", false)
            
            if (clave.isEmpty() || !autoOn) {
                stopSelf()
                return
            }

            val now = java.util.Calendar.getInstance()
            val diasGuardados = prefs.getStringList("flutter.dias") ?: emptyList()
            if (!diasGuardados.contains(now.get(java.util.Calendar.DAY_OF_WEEK).toString())) {
                stopSelf()
                return
            }

            val startH = prefs.getInt("flutter.inicio_hora", 22)
            val startM = prefs.getInt("flutter.inicio_min", 0)
            val endH = prefs.getInt("flutter.fin_hora", 22)
            val endM = prefs.getInt("flutter.fin_min", 30)
            
            val nowMin = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
            val startMin = startH * 60 + startM
            val endMin = endH * 60 + endM

            if (nowMin < startMin || nowMin >= endMin) {
                stopSelf()
                return
            }

            val fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            val locationRequest = LocationRequest.create().apply {
                interval = 5000
                fastestInterval = 2000
                priority = LocationRequest.PRIORITY_HIGH_ACCURACY
            }

            val dbRef = FirebaseDatabase.getInstance().reference.child("rooms").child(clave)
            
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                
                fusedLocationClient.requestLocationUpdates(
                    locationRequest,
                    { location ->
                        scope.launch(Dispatchers.IO) {
                            try {
                                dbRef.setValue(mapOf(
                                    "lat" to location.latitude,
                                    "lng" to location.longitude
                                ))
                                android.util.Log.d("LocationService", "📍 Ubicación: ${location.latitude}, ${location.longitude}")
                            } catch (e: Exception) {
                                android.util.Log.e("LocationService", "Error enviando", e)
                            }
                        }
                    },
                    null
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error", e)
            stopSelf()
        }
    }

    override fun onDestroy() {
        android.util.Log.d("LocationService", "Servicio destruido")
        scope.cancel()
        super.onDestroy()
    }
}
