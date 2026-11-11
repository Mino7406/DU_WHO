package com.example.du_who

import android.Manifest
import android.content.Context
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
                    "getCallerIdStatus" -> result.success(callerIdStatus())
                    "requestOverlayPermission" -> {
                        // "다른 앱 위에 표시"는 설정 화면에서 사용자가 직접 켜야 한다
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                            } catch (_: Exception) {}
                        }
                        result.success(null)
                    }
                    "setCallerIdEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        getSharedPreferences(PREFS, MODE_PRIVATE)
                            .edit().putBoolean(KEY_CALLER_ID_ENABLED, enabled).apply()
                        result.success(null)
                    }
                    "previewCallerId" -> {
                        // 실제 수신과 같은 경로(전체 화면·알림)로 미리보기를 띄운다
                        val number = call.argument<String>("number") ?: ""
                        Thread { CallOverlay.show(this, number, preview = true) }.start()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // 걸려온 학교 번호 알림(BETA)에 필요한 것들이 준비됐는지
    private fun callerIdStatus(): Map<String, Boolean> {
        fun granted(p: String) = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
        val notifications = if (Build.VERSION.SDK_INT >= 33)
            granted(Manifest.permission.POST_NOTIFICATIONS) else true
        val battery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
        else true
        return mapOf(
            "supported" to true,
            "enabled" to isCallerIdEnabled(this),
            "phone" to granted(Manifest.permission.READ_PHONE_STATE),
            "callLog" to granted(Manifest.permission.READ_CALL_LOG),
            "notifications" to notifications,
            "battery" to battery,
            // 수신 화면 위에 크게 띄우기(없으면 알림만 뜬다)
            "overlay" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                Settings.canDrawOverlays(this)),
        )
    }

    companion object {
        const val CHANNEL      = "du_who/call_overlay"
        const val PREFS        = "du_who_prefs"
        const val KEY_DB_PATH  = "db_path"
        const val KEY_IS_STAFF = "is_staff"
        const val KEY_CALLER_ID_ENABLED = "caller_id_enabled"

        fun isCallerIdEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_CALLER_ID_ENABLED, true)
        private const val REQ_CALL_LOG = 1002
    }
}
