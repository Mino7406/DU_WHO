package com.example.du_who

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager

class CallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        // 앱의 "걸려온 학교 번호 알림" 스위치가 꺼져 있으면 아무것도 하지 않는다
        if (!MainActivity.isCallerIdEnabled(context)) return
        val svcIntent = Intent(context, CallOverlayService::class.java)

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                @Suppress("DEPRECATION")
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""
                svcIntent.putExtra("action", "show")
                svcIntent.putExtra("phone_number", number)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(svcIntent)
                } else {
                    context.startService(svcIntent)
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE,
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                svcIntent.putExtra("action", "hide")
                try { context.startService(svcIntent) } catch (_: Exception) {}
            }
        }
    }
}
