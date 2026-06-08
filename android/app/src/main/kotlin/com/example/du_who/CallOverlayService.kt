package com.example.du_who

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.sqlite.SQLiteDatabase
import android.os.*

/**
 * 수신 전화 알림 서비스.
 * DB에서 발신자 교직원 정보를 조회한 뒤 헤드업 알림으로 표시한다.
 */
class CallOverlayService : Service() {

    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.getStringExtra("action") != "show") {
            cancelCallerNotification()
            stopSelf()
            return START_NOT_STICKY
        }

        val rawNumber = intent.getStringExtra("phone_number") ?: ""

        // 포그라운드 서비스 즉시 시작 (ANR 방지)
        startForegroundCompat()

        // DB 조회 → 알림 표시 → 서비스 종료
        Thread {
            val isStaff = getSharedPreferences(MainActivity.PREFS, MODE_PRIVATE)
                .getBoolean(MainActivity.KEY_IS_STAFF, false)
            val staff = queryStaff(rawNumber, isStaff)
            handler.post {
                showCallerNotification(rawNumber, staff, isStaff)
                stopForegroundCompat()
                stopSelf()
            }
        }.start()

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─── 발신자 알림 ──────────────────────────────────────────

    private fun showCallerNotification(number: String, staff: StaffInfo?, isStaff: Boolean) {
        // DB에 등록된 교직원 번호일 때만 알림 표시
        if (staff == null) return

        val nm = getSystemService(NotificationManager::class.java) ?: return

        val title = "📞 ${staff.name}"
        val body = buildString {
            if (staff.department.isNotEmpty()) append(staff.department)
            // 직위: 교직원 계정만 표시
            if (isStaff && staff.title.isNotEmpty()) {
                if (isNotEmpty()) append(" · ")
                append(staff.title)
            }
            if (staff.location.isNotEmpty()) {
                if (isNotEmpty()) append("  ")
                // 학생: 건물명만(요약), 교직원: 전체
                append(if (isStaff) staff.location else summarizeLocation(staff.location))
            }
            if (isEmpty()) append(number)
        }

        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CALLER_CH)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setTimeoutAfter(30_000L)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .build()
        }
        nm.notify(CALLER_NOTIF_ID, notif)
    }

    private fun cancelCallerNotification() {
        getSystemService(NotificationManager::class.java)?.cancel(CALLER_NOTIF_ID)
    }

    // ─── DB 조회 ─────────────────────────────────────────────

    private data class StaffInfo(
        val name: String,
        val department: String,
        val title: String,
        val location: String,
    )

    private fun queryStaff(rawNumber: String, isStaff: Boolean): StaffInfo? {
        val dbPath = getSharedPreferences(MainActivity.PREFS, MODE_PRIVATE)
            .getString(MainActivity.KEY_DB_PATH, null) ?: return null

        val cleaned = rawNumber
            .replace(Regex("^\\+82"), "0")
            .replace(Regex("[^\\d]"), "")
        if (cleaned.length < 4) return null

        return try {
            SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                // 학생: 교내전화(tel)만 매칭, 교직원: 교내+휴대전화 모두 매칭
                val (sql, args) = if (isStaff) {
                    val q = """
                        SELECT name, department, title, location FROM staff
                        WHERE REPLACE(REPLACE(tel,     '-',''),' ','') = ?
                           OR REPLACE(REPLACE(cell_tel,'-',''),' ','') = ?
                           OR (
                               LENGTH(REPLACE(REPLACE(tel,'-',''),' ','')) >= 4
                               AND REPLACE(REPLACE(tel,'-',''),' ','') NOT IN ('','0000')
                               AND ? LIKE '%' || REPLACE(REPLACE(tel,'-',''),' ','')
                           )
                        LIMIT 1
                    """.trimIndent()
                    Pair(q, arrayOf(cleaned, cleaned, cleaned))
                } else {
                    val q = """
                        SELECT name, department, title, location FROM staff
                        WHERE REPLACE(REPLACE(tel,'-',''),' ','') = ?
                           OR (
                               LENGTH(REPLACE(REPLACE(tel,'-',''),' ','')) >= 4
                               AND REPLACE(REPLACE(tel,'-',''),' ','') NOT IN ('','0000')
                               AND ? LIKE '%' || REPLACE(REPLACE(tel,'-',''),' ','')
                           )
                        LIMIT 1
                    """.trimIndent()
                    Pair(q, arrayOf(cleaned, cleaned))
                }
                db.rawQuery(sql, args).use { c ->
                    if (!c.moveToFirst()) return null
                    StaffInfo(
                        name       = c.getString(0) ?: return null,
                        department = c.getString(1) ?: "",
                        title      = c.getString(2) ?: "",
                        location   = c.getString(3) ?: "",
                    )
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    // 학생용: 건물명만 추출 ("공학관 301호" → "공학관")
    private fun summarizeLocation(location: String): String {
        val parts = location.trim().split(Regex("\\s+"))
        val summary = parts.takeWhile { p -> p.none { c -> c.isDigit() } }.joinToString(" ")
        return summary.ifEmpty { parts.firstOrNull() ?: location }
    }

    // ─── 포그라운드 서비스 ────────────────────────────────────

    private fun startForegroundCompat() {
        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, FG_CH)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle("DU-WHO")
                .setContentText("수신 전화 확인 중...")
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle("DU-WHO")
                .setContentText("수신 전화 확인 중...")
                .setPriority(Notification.PRIORITY_MIN)
                .setOngoing(true)
                .build()
        }
        try {
            when {
                Build.VERSION.SDK_INT >= 35 ->
                    startForeground(FG_NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                    startForeground(FG_NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                else ->
                    startForeground(FG_NOTIF_ID, notif)
            }
        } catch (_: Exception) {
            try { startForeground(FG_NOTIF_ID, notif) } catch (_: Exception) {}
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    // ─── 알림 채널 ────────────────────────────────────────────

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java) ?: return
            // 헤드업 배너: 수신 전화 교직원 정보
            nm.createNotificationChannel(
                NotificationChannel(CALLER_CH, "수신 전화 교직원 안내", NotificationManager.IMPORTANCE_HIGH)
            )
            // 포그라운드 서비스용 (최소 노출)
            nm.createNotificationChannel(
                NotificationChannel(FG_CH, "DU-WHO 백그라운드", NotificationManager.IMPORTANCE_MIN)
                    .apply { setSound(null, null) }
            )
        }
    }

    companion object {
        const val CALLER_CH     = "du_who_caller"
        const val CALLER_NOTIF_ID = 7004
        const val FG_CH         = "du_who_fg"
        const val FG_NOTIF_ID   = 7001
    }
}
