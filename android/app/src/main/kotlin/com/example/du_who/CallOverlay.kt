package com.example.du_who

import android.Manifest
import android.app.*
import android.content.Context
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * 걸려온 전화가 교직원 번호면 누구인지 보여준다.
 * "다른 앱 위에 표시" 권한이 있으면 기본 수신 화면을 덮는 전체 화면(이름·부서·받기/거절)을,
 * 없으면 헤드업 알림만 띄운다.
 *
 * 서비스를 쓰지 않고 수신 신호(CallReceiver)에서 바로 띄운다. 앱이 꺼져 있을 때는
 * 안드로이드가 포그라운드 서비스 시작을 막기 때문이다(Android 12+).
 */
object CallOverlay {

    private val handler = Handler(Looper.getMainLooper())

    // 수신 화면 위에 띄운 전체 화면
    private var overlay: View? = null
    private var overlayContext: Context? = null
    private val overlayTimeout = Runnable { overlayContext?.let { hide(it) } }

    /**
     * [rawNumber]를 DB에서 찾아 화면·알림을 띄운다. DB를 읽으므로 메인 스레드 밖에서 부른다.
     * [preview]면 실제 교직원 대신 예시 정보로 보여준다(앱의 "수신 화면 미리보기").
     */
    fun show(context: Context, rawNumber: String, preview: Boolean = false) {
        val app = context.applicationContext
        val isStaff = app.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
            .getBoolean(MainActivity.KEY_IS_STAFF, false)
        // DB에 등록된 교직원 번호일 때만 표시
        val staff = (if (preview) PREVIEW_SAMPLE else app.queryStaff(rawNumber, isStaff)) ?: return
        val text = callerText(rawNumber, staff, isStaff, preview)
        handler.post {
            app.createChannel()
            app.showCallerNotification(text)
            app.showOverlay(text, preview)
        }
    }

    /** 전화를 받았거나 끊겼다: 화면과 알림을 모두 치운다 */
    fun hide(context: Context) {
        val app = context.applicationContext
        handler.post {
            removeOverlay()
            app.getSystemService(NotificationManager::class.java)?.cancel(CALLER_NOTIF_ID)
        }
    }

    // ─── 표시할 문구 ──────────────────────────────────────────

    /** [headline]: 이름(또는 공용 번호의 부서), [lines]: 그 아래 부서·직위, 위치 */
    private class CallerText(val headline: String, val lines: List<String>, val number: String)

    private fun callerText(
        number: String,
        staff: StaffInfo,
        isStaff: Boolean,
        preview: Boolean,
    ): CallerText {
        val prefix = if (preview) "[미리보기] " else ""
        // 학생: 건물명만(요약), 교직원: 전체
        val location = if (isStaff) staff.location else summarizeLocation(staff.location)
        // 여러 명이 같이 쓰는 번호면 사람 대신 부서 단위로 보여준다
        if (staff.sharedCount > 1) {
            val names = staff.sharedNames.joinToString(", ") +
                if (staff.sharedCount > staff.sharedNames.size) " 외" else ""
            return CallerText(
                prefix + "${staff.department.ifEmpty { staff.name }} (${staff.sharedCount}명 공용)",
                listOf(names, location).filter { it.isNotEmpty() },
                number,
            )
        }
        // 직위: 교직원 계정만 표시
        val who = listOf(staff.department, if (isStaff) staff.title else "")
            .filter { it.isNotEmpty() }.joinToString(" · ")
        return CallerText(
            prefix + staff.name,
            listOf(who, location).filter { it.isNotEmpty() },
            number,
        )
    }

    // ─── 발신자 알림 ──────────────────────────────────────────

    private fun Context.showCallerNotification(text: CallerText) {
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val title = "📞 ${text.headline}"
        val body = text.lines.joinToString("  ").ifEmpty { text.number }

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

    // ─── 수신 화면 위 전체 화면 ───────────────────────────────

    private fun Context.dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    /** 기본 수신 화면을 덮는 화면을 띄운다. 권한이 없거나 실패하면 false */
    private fun Context.showOverlay(text: CallerText, preview: Boolean): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            return false
        }
        val wm = getSystemService(WindowManager::class.java) ?: return false
        removeOverlay()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            // 키 입력(음량 버튼으로 벨소리 끄기 등)은 뒤의 전화 앱이 그대로 받게 한다
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                @Suppress("DEPRECATION") WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            params.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        val view = buildOverlayView(text, preview)
        return try {
            wm.addView(view, params)
            overlay = view
            overlayContext = this
            // 끊김 신호를 놓쳐도 화면이 남지 않게 한다
            handler.postDelayed(overlayTimeout, if (preview) 20_000L else 90_000L)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun removeOverlay() {
        handler.removeCallbacks(overlayTimeout)
        val view = overlay ?: return
        val context = overlayContext
        overlay = null
        overlayContext = null
        try {
            context?.getSystemService(WindowManager::class.java)?.removeView(view)
        } catch (_: Exception) {}
    }

    private fun Context.buildOverlayView(text: CallerText, preview: Boolean): View {
        val ctx = this
        fun label(s: String, sp: Float, color: Int, bold: Boolean = false) = TextView(ctx).apply {
            this.text = s
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            setTextColor(color)
            gravity = Gravity.CENTER
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }
        val white = Color.WHITE
        val dim = Color.argb(200, 255, 255, 255)

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            // 대구대 DEEP GREEN → 어두운 녹색
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.rgb(0, 129, 109), Color.rgb(8, 40, 34)),
            )
            setPadding(dp(24), dp(56), dp(24), dp(56))
            // 빈 곳을 눌러도 뒤의 전화 화면이 눌리지 않게 한다
            isClickable = true
        }

        // 가운데: 이름, 부서·직위, 위치, 번호
        val info = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        // 화면을 켜고 쓰는 중에는 시스템의 수신 배너가 맨 위를 가리므로 위쪽은 비워 둔다
        info.addView(
            label("DU-WHO · 교직원 전화", 15f, dim, bold = true).apply { setPadding(0, 0, 0, dp(16)) }
        )
        info.addView(label(text.headline, 38f, white, bold = true))
        for (line in text.lines) {
            info.addView(
                label(line, 20f, white).apply { setPadding(0, dp(12), 0, 0) }
            )
        }
        if (text.number.isNotEmpty()) {
            info.addView(label(text.number, 17f, dim).apply { setPadding(0, dp(20), 0, 0) })
        }
        root.addView(info, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))

        // 아래: 거절 / 받기
        val buttons = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        buttons.addView(
            callButton("거절", Color.rgb(239, 68, 68), hangUp = true) {
                if (!preview && !declineCall()) fallbackToDialer()
                hide(ctx)
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        buttons.addView(
            callButton("받기", Color.rgb(34, 197, 94), hangUp = false) {
                if (!preview && !answerCall()) fallbackToDialer()
                hide(ctx)
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        root.addView(buttons)

        // 닫으면 기본 전화 화면이 그대로 나온다
        root.addView(
            label("닫고 기본 전화 화면 보기", 14f, white).apply {
                setPadding(dp(18), dp(10), dp(18), dp(10))
                background = GradientDrawable().apply {
                    cornerRadius = dp(20).toFloat()
                    setColor(Color.argb(50, 255, 255, 255))
                }
                setOnClickListener { hide(ctx) }
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(28) },
        )
        return root
    }

    private fun Context.callButton(text: String, color: Int, hangUp: Boolean, onClick: () -> Unit): View {
        val ctx = this
        val box = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        val circle = ImageView(ctx).apply {
            setImageResource(if (hangUp) R.drawable.ic_call_end else R.drawable.ic_call)
            setPadding(dp(20), dp(20), dp(20), dp(20))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(color)
            }
            contentDescription = text
            setOnClickListener { onClick() }
        }
        box.addView(circle, LinearLayout.LayoutParams(dp(76), dp(76)))
        box.addView(
            TextView(ctx).apply {
                this.text = text
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, dp(10), 0, 0)
            }
        )
        return box
    }

    // ─── 전화 받기 · 거절 ────────────────────────────────────

    private fun Context.canControlCall() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        checkSelfPermission(Manifest.permission.ANSWER_PHONE_CALLS) ==
        PackageManager.PERMISSION_GRANTED

    @Suppress("DEPRECATION")
    private fun Context.answerCall(): Boolean {
        if (!canControlCall() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            getSystemService(TelecomManager::class.java).acceptRingingCall()
            true
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun Context.declineCall(): Boolean {
        if (!canControlCall() || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        return try {
            getSystemService(TelecomManager::class.java).endCall()
        } catch (_: Exception) {
            false
        }
    }

    // 받기·거절을 대신 못 하면 화면을 치워 기본 전화 화면에서 하게 한다
    private fun Context.fallbackToDialer() {
        Toast.makeText(this, "기본 전화 화면에서 받아 주세요", Toast.LENGTH_LONG).show()
    }

    // ─── DB 조회 ─────────────────────────────────────────────

    private data class StaffInfo(
        val name: String,
        val department: String,
        val title: String,
        val location: String,
        // 같은 번호를 쓰는 사람 수와 이름 일부(공용 번호 표시용)
        val sharedCount: Int = 1,
        val sharedNames: List<String> = emptyList(),
    )

    private fun Context.queryStaff(rawNumber: String, isStaff: Boolean): StaffInfo? {
        val dbPath = getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
            .getString(MainActivity.KEY_DB_PATH, null) ?: return null

        val cleaned = rawNumber
            .replace(Regex("^\\+82"), "0")
            .replace(Regex("[^\\d]"), "")
        if (cleaned.length < 4) return null

        return try {
            SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                val args = arrayOf(cleaned, if (isStaff) "1" else "0")
                db.rawQuery(MATCH_SQL, args).use { c ->
                    val matches = mutableListOf<StaffInfo>()
                    var bestRank = -1
                    while (c.moveToNext()) {
                        val rank = c.getInt(4)
                        // 가장 정확한 순위의 결과만 사용 (휴대폰 일치 > 교내전화 일치 > 내선)
                        if (bestRank == -1) bestRank = rank
                        if (rank != bestRank) break
                        matches += StaffInfo(
                            name       = c.getString(0) ?: continue,
                            department = c.getString(1) ?: "",
                            title      = c.getString(2) ?: "",
                            location   = c.getString(3) ?: "",
                        )
                    }
                    val first = matches.firstOrNull() ?: return null
                    if (matches.size == 1) first
                    else first.copy(
                        sharedCount = matches.size,
                        sharedNames = matches.take(3).map { it.name },
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

    // ─── 알림 채널 ────────────────────────────────────────────

    private fun Context.createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 헤드업 배너: 수신 전화 교직원 정보
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(CALLER_CH, "수신 전화 교직원 안내", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    /** 미리보기 알림에 쓰는 예시 교직원(실제 사람이 아님) */
    private val PREVIEW_SAMPLE = StaffInfo(
        name = "홍길동 (예시)",
        department = "학생지원팀",
        title = "팀장",
        location = "본관 101호",
    )

    /**
     * 발신 번호 → 교직원 매칭. ?1 = 숫자만 남긴 수신 번호, ?2 = 교직원 계정이면 1.
     * 전체 번호가 정확히 같을 때만 매칭한다. 끝자리만 비교하면 4자리 내선번호(105건) 때문에
     * 관계없는 번호의 약 1%가 교직원으로 잘못 감지됐다.
     * 4자리 내선은 학교 국번(053-850, 053-650)이 붙은 번호로 걸려올 때만 매칭한다.
     * 학생: 교내전화만, 교직원: 휴대전화도 매칭. ios/Runner/StaffDatabase.swift 와 같은 SQL.
     */
    private val MATCH_SQL = """
        SELECT name, department, title, location,
               CASE WHEN ?2 = 1 AND c = ?1 THEN 0 WHEN t = ?1 THEN 1 ELSE 2 END AS rank
        FROM (
            SELECT name, department, title, location,
                   REPLACE(REPLACE(tel,     '-', ''), ' ', '') AS t,
                   REPLACE(REPLACE(cell_tel,'-', ''), ' ', '') AS c
            FROM staff
        )
        WHERE (?2 = 1 AND c = ?1)
           OR t = ?1
           OR (LENGTH(t) = 4 AND t <> '0000' AND ?1 IN ('053850' || t, '053650' || t))
        ORDER BY rank
        LIMIT 20
    """.trimIndent()

    private const val CALLER_CH     = "du_who_caller"
    private const val CALLER_NOTIF_ID = 7004
}
