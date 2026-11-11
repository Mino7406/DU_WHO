package com.example.du_who

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

class CallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        // 앱의 "걸려온 학교 번호 알림" 스위치가 꺼져 있으면 아무것도 하지 않는다
        if (!MainActivity.isCallerIdEnabled(context)) return

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                @Suppress("DEPRECATION")
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""
                // DB 조회는 다른 스레드에서. 끝날 때까지 수신 처리를 붙잡아 둔다
                val pending = goAsync()
                Thread {
                    try {
                        CallOverlay.show(context, number)
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
            TelephonyManager.EXTRA_STATE_IDLE,
            TelephonyManager.EXTRA_STATE_OFFHOOK -> CallOverlay.hide(context)
        }
    }
}
