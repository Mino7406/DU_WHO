package com.example.du_who

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveDbPath" -> {
                        val path = call.argument<String>("path") ?: ""
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit().putString(KEY_DB_PATH, path).apply()
                        result.success(null)
                    }
                    "checkCallLogPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
                        else true
                        result.success(granted)
                    }
                    "requestCallLogPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            requestPermissions(arrayOf(Manifest.permission.READ_CALL_LOG), REQ_CALL_LOG)
                        }
                        result.success(null)
                    }
                    "saveUserRole" -> {
                        val isStaff = call.argument<Boolean>("isStaff") ?: false
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit().putBoolean(KEY_IS_STAFF, isStaff).apply()
                        result.success(null)
                    }
                    "requestBatteryExemption" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(PowerManager::class.java)
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                try {
                                    startActivity(
                                        Intent(
                                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                            Uri.parse("package:$packageName")
                                        )
                                    )
                                } catch (_: Exception) {}
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val CHANNEL      = "du_who/call_overlay"
        const val PREFS        = "du_who_prefs"
        const val KEY_DB_PATH  = "db_path"
        const val KEY_IS_STAFF = "is_staff"
        private const val REQ_CALL_LOG = 1002
    }
}
