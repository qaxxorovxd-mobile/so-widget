package uz.qaxxorov.so_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.CornerPathEffect
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Native media widgets (Now Playing + the Media collection). Drawn on a Canvas at the widget's
 * exact size and redrawn the moment the media session changes — no Flutter engine involved.
 */
object SoNowPlaying {
    const val ID = "nowplaying"

    /** So Widget id -> design. */
    val VARIANTS = mapOf(
        "nowplaying" to "classic",
        "m_vinyl" to "vinyl",
        "m_cover" to "cover",
        "m_wave" to "wave",
        "m_disc" to "disc",
        "m_type" to "type",
        "m_capsule" to "capsule",
    )

    fun isMedia(id: String?) = id != null && VARIANTS.containsKey(id)

    private val main = Handler(Looper.getMainLooper())
    private var appCtx: Context? = null
    private val tick = Runnable { appCtx?.let { updateAll(it) } }

    data class Style(
        val bg: Int,
        val fg: Int,
        val accent: Int,
        val glow: Boolean,
        val glowStrength: Float,
        val radius: Float,
        val bgOpacity: Float = 1f,
        val borderWidth: Float = 1f,
        val borderOpacity: Float = 0.12f,
        val font: String = "Inter",
        val weight: Int = 0,
        val textScale: Float = 1f,
    )

    data class Controls(val prev: RectF? = null, val toggle: RectF? = null, val next: RectF? = null)

    fun parseStyle(json: String?): Style = try {
        val j = JSONObject(json ?: "{}")
        val border = j.optBoolean("border", true)
        Style(
            j.optLong("bg", 0xFF141414).toInt(),
            j.optLong("fg", 0xFFFFFFFF).toInt(),
            j.optLong("accent", 0xFFFFFFFF).toInt(),
            j.optBoolean("glow", true),
            j.optDouble("glowStrength", 0.6).toFloat(),
            j.optDouble("radius", 38.0).toFloat(),
            j.optDouble("bgOpacity", 1.0).toFloat().coerceIn(0.25f, 1f),
            if (border) j.optDouble("borderWidth", 1.0).toFloat() else 0f,
            j.optDouble("borderOpacity", 0.12).toFloat(),
            j.optString("font", "Inter"),
            j.optInt("weight", 0),
            j.optDouble("textScale", 1.0).toFloat().coerceIn(0.8f, 1.15f),
        )
    } catch (_: Exception) {
        Style(0xFF141414.toInt(), Color.WHITE, Color.WHITE, true, 0.6f, 38f)
    }

    private val fontCache = mutableMapOf<String, Typeface?>()

    /**
     * Uses the same font file Flutter downloaded (google_fonts caches it in filesDir as
     * "Family-Weight_hash.ttf"), so native widgets match the rest of So Widget.
     */
    fun typeface(c: Context, family: String, weights: List<String>, fallback: Typeface): Typeface {
        val key = family + weights.joinToString()
        fontCache[key]?.let { return it }
        val prefix = family.replace(" ", "")
        val files = try { c.filesDir.listFiles()?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
        var tf: Typeface? = null
        for (w in weights) {
            val f = files.firstOrNull { it.name.startsWith("$prefix-${w}_") && it.name.endsWith(".ttf") } ?: continue
            tf = try { Typeface.createFromFile(f) } catch (_: Exception) { null }
            if (tf != null) break
        }
        if (tf != null) fontCache[key] = tf
        return tf ?: fallback
    }

    /** Weight names from light to heavy, as google_fonts names the files. */
    private val weightNames = listOf("Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Black")

    fun weightsFor(base: Int, shift: Int): List<String> {
        val i = (base + shift).coerceIn(0, weightNames.size - 1)
        return listOf(weightNames[i]) + weightNames.indices.sortedBy { abs(it - i) }.drop(1).map { weightNames[it] }
    }

    private fun instances(c: Context): List<Triple<Int, String, String>> {
        val prefs = HomeWidgetPlugin.getData(c)
        val mgr = AppWidgetManager.getInstance(c)
        return SoHome.providers.flatMap { (slot, cls) ->
            mgr.getAppWidgetIds(ComponentName(c, cls)).toList().mapNotNull { wid: Int ->
                val id = prefs.getString(SoHome.instKey(wid), null)
                if (id != null && isMedia(id)) Triple<Int, String, String>(wid, slot, id) else null
            }
        }
    }

    /** Redraws every media widget; keeps progress moving while music plays and the screen is on. */
    fun updateAll(context: Context) {
        val c = context.applicationContext
        appCtx = c
        main.removeCallbacks(tick)
        val list = instances(c)
        if (list.isEmpty()) return
        val now = SoMedia.now(c)
        val mgr = AppWidgetManager.getInstance(c)
        for ((wid, slot, id) in list) {
            try {
                render(c, mgr, wid, slot, id, now)
            } catch (_: Exception) {
            }
        }
        val screenOn = (c.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
        if (now.playing && screenOn) main.postDelayed(tick, 1000)
    }

    private fun layoutFor(wDp: Int, hDp: Int) = when {
        hDp < 118 -> "strip"
        wDp < 230 -> "small"
        hDp <= 230 -> "medium"
        else -> "large"
    }

    /** Bitmap for the in-app preview (same renderer as the home screen). */
    fun preview(c: Context, id: String, wDp: Int, hDp: Int, styleJson: String?): ByteArray {
        val d = c.resources.displayMetrics.density.coerceAtMost(2.6f)
        val now = SoMedia.now(c)
        val bmp = Bitmap.createBitmap((wDp * d).toInt(), (hDp * d).toInt(), Bitmap.Config.ARGB_8888)
        Painter(c, Canvas(bmp), d, parseStyle(styleJson), bmp.width.toFloat(), bmp.height.toFloat(), min(wDp, hDp))
            .draw(VARIANTS[id] ?: "classic", layoutFor(wDp, hDp), now)
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }

    fun render(
        c: Context,
        mgr: AppWidgetManager,
        wid: Int,
        slot: String,
        id: String = ID,
        now: SoMedia.Now = SoMedia.now(c),
    ) {
        val st = parseStyle(HomeWidgetPlugin.getData(c).getString("so_style_$id", null))
        val d = c.resources.displayMetrics.density

        val opts = mgr.getAppWidgetOptions(wid)
        val fallback = when (slot) {
            "small" -> 170 to 170
            "medium" -> 360 to 170
            else -> 360 to 380
        }
        var wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        var hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        if (wDp < 60 || hDp < 60) {
            wDp = fallback.first
            hDp = fallback.second
        }
        wDp = wDp.coerceIn(80, 600)
        hDp = hDp.coerceIn(80, 700)

        val w = (wDp * d).toInt()
        val h = (hDp * d).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val ctl = Painter(c, Canvas(bmp), d, st, w.toFloat(), h.toFloat(), min(wDp, hDp))
            .draw(VARIANTS[id] ?: "classic", layoutFor(wDp, hDp), now)

        val views = RemoteViews(c.packageName, R.layout.so_media)
        views.setImageViewBitmap(R.id.np_image, bmp)
        fun place(container: Int, button: Int, r: RectF?, action: String) {
            if (r == null || !now.hasTrack) {
                views.setViewVisibility(container, View.GONE)
                return
            }
            views.setViewVisibility(container, View.VISIBLE)
            views.setViewPadding(container, r.left.toInt(), r.top.toInt(), (w - r.right).toInt(), (h - r.bottom).toInt())
            views.setOnClickPendingIntent(button, action(c, wid, action))
        }
        place(R.id.np_c_prev, R.id.np_prev, ctl.prev, "previous")
        place(R.id.np_c_toggle, R.id.np_toggle, ctl.toggle, "toggle")
        place(R.id.np_c_next, R.id.np_next, ctl.next, "next")
        // No skip buttons drawn? Then the left edge goes back and the right edge skips ahead.
        val edge = w * 0.28f
        place(R.id.np_c_left, R.id.np_left, if (ctl.prev == null) RectF(0f, 0f, edge, h.toFloat()) else null, "previous")
        place(R.id.np_c_right, R.id.np_right, if (ctl.next == null) RectF(w - edge, 0f, w.toFloat(), h.toFloat()) else null, "next")

        val open = when {
            !now.allowed -> PendingIntent.getActivity(
                c, 7700 + wid,
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            now.controller?.sessionActivity != null -> now.controller.sessionActivity
            else -> HomeWidgetLaunchIntent.getActivity(c, MainActivity::class.java, Uri.parse("sowidget://open?id=$id&wid=$wid"))
        }
        views.setOnClickPendingIntent(R.id.np_root, open)
        mgr.updateAppWidget(wid, views)
    }

    private fun action(c: Context, wid: Int, a: String): PendingIntent {
        val i = Intent(c, SoMediaActionReceiver::class.java).putExtra("a", a).setData(Uri.parse("sowidget://media/$a/$wid"))
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(c, (a.hashCode() * 31) + wid, i, flags)
    }

    /** All drawing. [u] converts dp to px. */
    private class Painter(
        val ctx: Context,
        val cv: Canvas,
        val d: Float,
        val st: Style,
        val w: Float,
        val h: Float,
        minDp: Int,
    ) {
        fun u(v: Float) = v * d
        val pad = u(if (minDp < 200) 15f else 18f)
        val radius = min(st.radius / 170f * minDp * d, min(w, h) / 2f)
        val fg = st.fg
        val accent = if (st.accent == st.fg) st.fg else st.accent

        /** Waveform / ring highlight: style accent, or a warm orange when the style is monochrome. */
        val hot = if (st.accent == st.fg) Color.rgb(255, 106, 26) else st.accent
        val glow = if (st.glow) st.glowStrength.coerceIn(0f, 1f) else 0f
        val bold: Typeface = typeface(ctx, st.font, weightsFor(3, st.weight), Typeface.create("sans-serif", Typeface.BOLD))
        val medium: Typeface = typeface(ctx, st.font, weightsFor(2, st.weight), Typeface.create("sans-serif-medium", Typeface.NORMAL))
        val regular: Typeface = typeface(ctx, st.font, weightsFor(1, st.weight), Typeface.create("sans-serif", Typeface.NORMAL))
        val full = RectF(0f, 0f, w, h)

        fun alpha(color: Int, a: Float) =
            Color.argb((Color.alpha(color) * a).toInt().coerceIn(0, 255), Color.red(color), Color.green(color), Color.blue(color))

        fun lighten(color: Int, f: Float) = Color.rgb(
            (Color.red(color) + (255 - Color.red(color)) * f).toInt(),
            (Color.green(color) + (255 - Color.green(color)) * f).toInt(),
            (Color.blue(color) + (255 - Color.blue(color)) * f).toInt(),
        )

        fun avgColor(b: Bitmap): Int = try {
            Bitmap.createScaledBitmap(b, 1, 1, true).getPixel(0, 0)
        } catch (_: Exception) {
            accent
        }

        fun p(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }

        // ───────────── shared pieces ─────────────

        fun background(tint: Int?) {
            cv.drawRoundRect(full, radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, w, h, alpha(lighten(st.bg, 0.06f), st.bgOpacity), alpha(st.bg, st.bgOpacity), Shader.TileMode.CLAMP)
            })
            if (tint != null) {
                cv.drawRect(full, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = RadialGradient(w * 0.15f, h * 0.2f, max(w, h) * 0.9f, alpha(tint, 0.5f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
                })
            }
        }

        fun border() {
            if (st.borderWidth <= 0f || st.borderOpacity <= 0f) return
            val sw = u(st.borderWidth)
            cv.drawRoundRect(RectF(sw / 2, sw / 2, w - sw / 2, h - sw / 2), radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = sw
                color = alpha(fg, st.borderOpacity)
            })
        }

        fun coverShader(b: Bitmap, r: RectF): BitmapShader {
            val s = BitmapShader(b, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            val scale = max(r.width() / b.width, r.height() / b.height)
            s.setLocalMatrix(Matrix().apply {
                setScale(scale, scale)
                postTranslate(r.left + (r.width() - b.width * scale) / 2, r.top + (r.height() - b.height * scale) / 2)
            })
            return s
        }

        fun art(b: Bitmap?, r: RectF, corner: Float, tint: Int, shadow: Boolean = true) {
            if (shadow && glow > 0) {
                cv.drawRoundRect(r, corner, corner, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = alpha(tint, 0.55f * glow)
                    maskFilter = BlurMaskFilter(u(14f) * glow + u(4f), BlurMaskFilter.Blur.NORMAL)
                })
            }
            if (b == null) {
                cv.drawRoundRect(r, corner, corner, p(lighten(st.bg, 0.08f)))
                cv.drawRoundRect(r, corner, corner, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(r.left, r.top, r.right, r.bottom, alpha(hot, 0.6f), alpha(fg, 0.08f), Shader.TileMode.CLAMP)
                })
                note(r.centerX(), r.centerY(), min(r.width(), r.height()) * 0.32f, fg)
                return
            }
            cv.drawRoundRect(r, corner, corner, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { shader = coverShader(b, r) })
        }

        fun artCircle(b: Bitmap?, cx: Float, cy: Float, r: Float, noteIcon: Boolean = true) {
            val rect = RectF(cx - r, cy - r, cx + r, cy + r)
            if (b == null) {
                cv.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(rect.left, rect.top, rect.right, rect.bottom, alpha(hot, 0.6f), alpha(fg, 0.1f), Shader.TileMode.CLAMP)
                })
                if (noteIcon) note(cx, cy, r * 0.6f, fg)
                return
            }
            cv.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { shader = coverShader(b, rect) })
        }

        /** Soft blurred artwork filling the widget (downscale + upscale). */
        fun blurredArt(b: Bitmap?, tint: Int?) {
            background(tint)
            if (b == null) return
            val small = Bitmap.createScaledBitmap(b, 10, max(1, (10f * b.height / b.width).toInt()), true)
            val r = RectF(-u(20f), -u(20f), w + u(20f), h + u(20f))
            cv.drawRect(full, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { shader = coverShader(small, r) })
            cv.drawRect(full, p(alpha(Color.BLACK, 0.42f)))
        }

        fun note(cx: Float, cy: Float, s: Float, color: Int) {
            val pt = p(color)
            cv.drawCircle(cx - s * 0.28f, cy + s * 0.32f, s * 0.22f, pt)
            cv.drawRect(cx - s * 0.1f, cy - s * 0.5f, cx - s * 0.02f, cy + s * 0.32f, pt)
            cv.drawPath(Path().apply {
                moveTo(cx - s * 0.1f, cy - s * 0.5f)
                lineTo(cx + s * 0.38f, cy - s * 0.32f)
                lineTo(cx + s * 0.38f, cy - s * 0.12f)
                lineTo(cx - s * 0.02f, cy - s * 0.28f)
                close()
            }, pt)
        }

        fun tp(sizeDp: Float, color: Int, face: Typeface, glowIt: Boolean) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = u(sizeDp * st.textScale)
            this.color = color
            typeface = face
            letterSpacing = if (sizeDp > 16) -0.02f else 0f
            if (glowIt && glow > 0) setShadowLayer(u(6f) + u(10f) * glow, 0f, 0f, alpha(color, 0.55f * glow))
        }

        /** align: 0 left, 1 center, 2 right (x is the anchor). */
        fun text(t: String, x: Float, y: Float, maxW: Float, sizeDp: Float, color: Int, face: Typeface, glowIt: Boolean = false, align: Int = 0) {
            val paint = tp(sizeDp, color, face, glowIt)
            val s = TextUtils.ellipsize(t, paint, max(1f, maxW), TextUtils.TruncateAt.END).toString()
            val tw = paint.measureText(s)
            val dx = when (align) {
                1 -> x - tw / 2
                2 -> x - tw
                else -> x
            }
            cv.drawText(s, dx, y, paint)
        }

        fun bar(l: Float, top: Float, r: Float, hh: Float, v: Float, color: Int = accent, knob: Boolean = true) {
            val rad = hh / 2
            cv.drawRoundRect(RectF(l, top, r, top + hh), rad, rad, p(alpha(fg, 0.16f)))
            val fill = l + (r - l) * v.coerceIn(0f, 1f)
            if (fill <= l + hh) return
            val fr = RectF(l, top, fill, top + hh)
            if (glow > 0) {
                cv.drawRoundRect(fr, rad, rad, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.color = alpha(color, 0.7f * glow)
                    maskFilter = BlurMaskFilter(u(5f) + u(6f) * glow, BlurMaskFilter.Blur.NORMAL)
                })
            }
            cv.drawRoundRect(fr, rad, rad, p(color))
            if (knob) cv.drawCircle(fill, top + rad, hh * 1.25f, p(fg))
        }

        /** Audio-style waveform; bars before [v] are lit. Deterministic per track. */
        fun waveform(r: RectF, v: Float, seed: Int, barW: Float = u(2.4f), gap: Float = u(2.2f)) {
            val n = max(8, ((r.width() + gap) / (barW + gap)).toInt())
            val total = n * barW + (n - 1) * gap
            var x = r.left + (r.width() - total) / 2
            var s = seed.toLong() and 0xffffffffL
            val lit = (v.coerceIn(0f, 1f) * n).toInt()
            val litPaint = p(hot)
            val offPaint = p(alpha(fg, 0.28f))
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = alpha(hot, 0.6f * glow)
                maskFilter = BlurMaskFilter(u(4f) + u(5f) * glow, BlurMaskFilter.Blur.NORMAL)
            }
            for (i in 0 until n) {
                s = (s * 1103515245L + 12345L) and 0x7fffffffL
                val rnd = (s % 1000) / 1000f
                val env = 0.35f + 0.65f * abs(sin(i * 0.33f + seed % 7))
                // A few "quiet" dots like the reference.
                val hh = if (rnd < 0.12f) barW else max(barW, r.height() * env * (0.35f + 0.65f * rnd))
                val top = r.centerY() - hh / 2
                val rect = RectF(x, top, x + barW, top + hh)
                if (i < lit && glow > 0) cv.drawRoundRect(rect, barW / 2, barW / 2, glowPaint)
                // Fade the unplayed edges a little.
                val fade = if (i >= lit) (1f - 0.6f * abs(i - n / 2f) / (n / 2f)) else 1f
                cv.drawRoundRect(rect, barW / 2, barW / 2, if (i < lit) litPaint else p(alpha(offPaint.color, fade)))
                x += barW + gap
            }
        }

        fun eq(right: Float, bottom: Float, hh: Float, on: Boolean) {
            val heights = if (on) floatArrayOf(0.55f, 1f, 0.7f, 0.85f) else floatArrayOf(0.3f, 0.3f, 0.3f, 0.3f)
            val bw = u(3f)
            val gap = u(2.5f)
            val pt = p(if (on) hot else alpha(fg, 0.35f))
            for (i in heights.indices) {
                val x = right - (heights.size - i) * (bw + gap) + gap
                cv.drawRoundRect(RectF(x, bottom - hh * heights[i], x + bw, bottom), bw / 2, bw / 2, pt)
            }
        }

        fun playIcon(cx: Float, cy: Float, s: Float, color: Int) {
            cv.drawPath(Path().apply {
                moveTo(cx - s * 0.32f, cy - s * 0.42f)
                lineTo(cx + s * 0.45f, cy)
                lineTo(cx - s * 0.32f, cy + s * 0.42f)
                close()
            }, p(color).apply { pathEffect = CornerPathEffect(s * 0.12f) })
        }

        fun pauseIcon(cx: Float, cy: Float, s: Float, color: Int) {
            val pt = p(color)
            val bw = s * 0.26f
            val r = bw * 0.35f
            cv.drawRoundRect(RectF(cx - s * 0.34f, cy - s * 0.42f, cx - s * 0.34f + bw, cy + s * 0.42f), r, r, pt)
            cv.drawRoundRect(RectF(cx + s * 0.34f - bw, cy - s * 0.42f, cx + s * 0.34f, cy + s * 0.42f), r, r, pt)
        }

        fun toggleIcon(cx: Float, cy: Float, s: Float, color: Int, playing: Boolean) =
            if (playing) pauseIcon(cx, cy, s, color) else playIcon(cx + s * 0.06f, cy, s, color)

        /** |◀ style (bar + triangle) like the reference. */
        fun skipIcon(cx: Float, cy: Float, s: Float, color: Int, forward: Boolean) {
            val pt = p(color).apply { pathEffect = CornerPathEffect(s * 0.08f) }
            val dir = if (forward) 1f else -1f
            cv.drawPath(Path().apply {
                moveTo(cx - dir * s * 0.32f, cy - s * 0.38f)
                lineTo(cx + dir * s * 0.28f, cy)
                lineTo(cx - dir * s * 0.32f, cy + s * 0.38f)
                close()
            }, pt)
            val bx = cx + dir * s * 0.3f
            val bw = s * 0.14f
            cv.drawRoundRect(RectF(min(bx, bx + dir * bw), cy - s * 0.38f, max(bx, bx + dir * bw), cy + s * 0.38f), bw / 2, bw / 2, p(color))
        }

        fun glass(r: RectF, corner: Float, filled: Boolean = false) {
            cv.drawRoundRect(r, corner, corner, p(if (filled) fg else alpha(fg, 0.09f)))
            if (!filled) {
                cv.drawRoundRect(r, corner, corner, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = u(0.8f)
                    color = alpha(fg, 0.08f)
                })
            }
        }

        fun glowCircle(cx: Float, cy: Float, r: Float, color: Int) {
            if (glow <= 0) return
            cv.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = alpha(color, 0.45f * glow)
                maskFilter = BlurMaskFilter(u(8f) + u(8f) * glow, BlurMaskFilter.Blur.NORMAL)
            })
        }

        /** Circle prev / wide pill play / circle next — the reference control row. */
        fun pillRow(r: RectF, playing: Boolean): Controls {
            val b = r.height()
            val gap = u(6f)
            val prev = RectF(r.left, r.top, r.left + b, r.bottom)
            val next = RectF(r.right - b, r.top, r.right, r.bottom)
            val mid = RectF(prev.right + gap, r.top, next.left - gap, r.bottom)
            glass(prev, b / 2)
            glass(next, b / 2)
            glass(mid, b / 2)
            val ic = b * 0.4f
            skipIcon(prev.centerX(), prev.centerY(), ic, fg, false)
            skipIcon(next.centerX(), next.centerY(), ic, fg, true)
            toggleIcon(mid.centerX(), mid.centerY(), ic, fg, playing)
            return Controls(prev, mid, next)
        }

        /** Three round buttons, the middle one solid. */
        fun circleRow(r: RectF, playing: Boolean, plain: Boolean = false): Controls {
            val b = min(r.height(), u(46f))
            val cy = r.centerY()
            val xs = listOf(r.left + r.width() / 6, r.centerX(), r.right - r.width() / 6)
            val rects = xs.map { RectF(it - b / 2, cy - b / 2, it + b / 2, cy + b / 2) }
            if (!plain) {
                glass(rects[0], b / 2)
                glass(rects[2], b / 2)
                glowCircle(xs[1], cy, b / 2, fg)
                glass(rects[1], b / 2, filled = true)
            }
            skipIcon(xs[0], cy, b * 0.38f, fg, false)
            skipIcon(xs[2], cy, b * 0.38f, fg, true)
            toggleIcon(xs[1], cy, b * 0.42f, if (plain) fg else st.bg, playing)
            // Bigger tap areas than the drawn buttons.
            val third = r.width() / 3
            return Controls(
                RectF(r.left, r.top, r.left + third, r.bottom),
                RectF(r.left + third, r.top, r.right - third, r.bottom),
                RectF(r.right - third, r.top, r.right, r.bottom),
            )
        }

        fun soloButton(r: RectF, playing: Boolean, filled: Boolean = true): Controls {
            val b = min(r.width(), r.height())
            if (filled) glowCircle(r.centerX(), r.centerY(), b / 2, fg)
            glass(r, b / 2, filled)
            toggleIcon(r.centerX(), r.centerY(), b * 0.42f, if (filled) st.bg else fg, playing)
            return Controls(toggle = r)
        }

        fun time(ms: Long): String {
            val s = ms / 1000
            return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
        }

        fun vinyl(cx: Float, cy: Float, r: Float, label: Int, angle: Float) {
            cv.drawCircle(cx, cy + r * 0.04f, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = alpha(Color.BLACK, 0.55f)
                maskFilter = BlurMaskFilter(r * 0.08f + 1f, BlurMaskFilter.Blur.NORMAL)
            })
            cv.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(cx, cy, r, intArrayOf(Color.rgb(28, 28, 30), Color.rgb(12, 12, 13), Color.rgb(22, 22, 24)), floatArrayOf(0.3f, 0.85f, 1f), Shader.TileMode.CLAMP)
            })
            val groove = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = max(1f, r * 0.006f)
                color = Color.argb(30, 255, 255, 255)
            }
            var rr = r * 0.4f
            while (rr < r * 0.97f) {
                cv.drawCircle(cx, cy, rr, groove)
                rr += r * 0.045f
            }
            // Light sheen that rotates with playback.
            val sheen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = r * 0.5f
                color = Color.argb(26, 255, 255, 255)
            }
            val arc = RectF(cx - r * 0.72f, cy - r * 0.72f, cx + r * 0.72f, cy + r * 0.72f)
            cv.drawArc(arc, angle, 28f, false, sheen)
            cv.drawArc(arc, angle + 180f, 28f, false, sheen)
            cv.drawCircle(cx, cy, r * 0.32f, p(label))
            cv.drawCircle(cx, cy, r * 0.32f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(cx - r * 0.1f, cy - r * 0.1f, r * 0.32f, Color.argb(60, 255, 255, 255), Color.TRANSPARENT, Shader.TileMode.CLAMP)
            })
            cv.drawCircle(cx, cy, r * 0.035f, p(Color.rgb(10, 10, 10)))
        }

        fun ring(cx: Float, cy: Float, r: Float, stroke: Float, v: Float) {
            val rect = RectF(cx - r, cy - r, cx + r, cy + r)
            cv.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                color = alpha(fg, 0.14f)
            })
            val sweep = 360f * v.coerceIn(0f, 1f)
            if (sweep <= 0f) return
            if (glow > 0) {
                cv.drawArc(rect, -90f, sweep, false, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = stroke
                    strokeCap = Paint.Cap.ROUND
                    color = alpha(hot, 0.7f * glow)
                    maskFilter = BlurMaskFilter(u(4f) + u(6f) * glow, BlurMaskFilter.Blur.NORMAL)
                })
            }
            cv.drawArc(rect, -90f, sweep, false, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
                color = hot
            })
            val a = Math.toRadians((-90f + sweep).toDouble())
            cv.drawCircle(cx + r * cos(a).toFloat(), cy + r * sin(a).toFloat(), stroke * 0.75f, p(fg))
        }

        // ───────────── entry ─────────────

        fun draw(variant: String, layout: String, n: SoMedia.Now): Controls {
            cv.save()
            cv.clipPath(Path().apply { addRoundRect(full, radius, radius, Path.Direction.CW) })
            val tint = n.art?.let { avgColor(it) }
            val result = if (!n.hasTrack) {
                empty(layout, n)
                Controls()
            } else {
                if (layout == "strip") stripDesign(n, tint, variant) else when (variant) {
                    "vinyl" -> vinylDesign(layout, n, tint)
                    "cover" -> coverDesign(layout, n, tint)
                    "wave" -> waveDesign(layout, n, tint)
                    "disc" -> discDesign(layout, n, tint)
                    "type" -> typeDesign(layout, n, tint)
                    "capsule" -> capsuleDesign(layout, n, tint)
                    else -> classicDesign(layout, n, tint)
                }
            }
            // Subtle chevrons where the edges skip tracks.
            if (n.hasTrack) {
                val tf = SoDevices.icons(ctx)
                if (tf != null) {
                    val ink = if (variant == "cover" || variant == "capsule") Color.WHITE else fg
                    val hint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        typeface = tf
                        textSize = u(13f)
                        color = alpha(ink, 0.35f)
                        textAlign = Paint.Align.CENTER
                    }
                    val y = h / 2 + u(4.5f)
                    if (result.prev == null) cv.drawText(String(Character.toChars(SoDevices.G_CHEVRON_LEFT)), u(7f), y, hint)
                    if (result.next == null) cv.drawText(String(Character.toChars(SoDevices.G_CHEVRON_RIGHT)), w - u(7f), y, hint)
                }
            }
            cv.restore()
            border()
            return result
        }

        val dim get() = alpha(fg, 0.5f)
        fun progress(n: SoMedia.Now) = if (n.duration > 0) n.position.toFloat() / n.duration else 0f
        fun status(n: SoMedia.Now) = (if (n.playing) "Now playing" else "Paused") + if (n.app.isNotEmpty()) " · ${n.app}" else ""
        fun both(n: SoMedia.Now) = if (n.artist.isEmpty()) n.title else "${n.artist} – ${n.title}"
        fun seed(n: SoMedia.Now) = (n.title + n.artist).hashCode()

        /** One row (2x1, 3x1, 4x1): artwork, title, artist, play / next. */
        fun stripDesign(n: SoMedia.Now, tint: Int?, variant: String): Controls {
            val onImage = variant == "cover" || variant == "capsule"
            if (onImage) blurredArt(n.art, tint) else background(tint)
            val ink = if (onImage) Color.WHITE else fg
            val p = min(u(10f), h * 0.16f)
            val a = h - p * 2
            val ar = RectF(p, p, p + a, p + a)
            if (variant == "disc") {
                artCircle(n.art, ar.centerX(), ar.centerY(), a / 2 - u(3f), noteIcon = n.art == null)
                ring(ar.centerX(), ar.centerY(), a / 2 - u(1.5f), u(2.5f), progress(n))
            } else {
                art(n.art, ar, min(radius * 0.6f, a * 0.28f), tint ?: hot, shadow = false)
            }
            val btn = min(a * 0.82f, u(40f))
            val right = w - p - u(2f)
            val toggle = RectF(right - btn, h / 2 - btn / 2, right, h / 2 + btn / 2)
            val showNext = w > u(200f)
            val next = if (showNext) RectF(toggle.left - u(4f) - btn, toggle.top, toggle.left - u(4f), toggle.bottom) else null
            glowCircle(toggle.centerX(), toggle.centerY(), btn / 2, ink)
            cv.drawCircle(toggle.centerX(), toggle.centerY(), btn / 2, p(ink))
            toggleIcon(toggle.centerX(), toggle.centerY(), btn * 0.42f, if (onImage) Color.BLACK else st.bg, n.playing)
            if (next != null) skipIcon(next.centerX(), next.centerY(), btn * 0.36f, ink, true)
            val tx = ar.right + u(12f)
            val tw = (next?.left ?: toggle.left) - u(6f) - tx
            val twoLines = h > u(64f)
            if (variant == "wave" && w > u(260f)) {
                waveform(RectF(tx, h / 2 + u(8f), tx + tw, h - p), progress(n), seed(n), u(1.8f), u(1.6f))
                text(n.title, tx, h / 2 - u(2f), tw, 14f, ink, bold, glowIt = true)
            } else if (twoLines) {
                text(n.title, tx, h / 2 - u(1f), tw, 15f, ink, bold, glowIt = true)
                text(n.artist, tx, h / 2 + u(16f), tw, 12f, alpha(ink, 0.6f), medium)
            } else {
                text(both(n), tx, h / 2 + u(5f), tw, 14f, ink, bold, glowIt = true)
            }
            if (n.duration > 0 && variant != "wave" && variant != "disc") {
                bar(tx, h - p * 0.55f - u(2f), tx + tw, u(2.5f), progress(n), hot, knob = false)
            }
            return Controls(next = next, toggle = toggle)
        }

        fun empty(layout: String, n: SoMedia.Now) {
            background(null)
            if (layout == "strip") {
                val s = h * 0.36f
                note(h / 2, h / 2, s, fg)
                text(if (!n.allowed) "Tap to enable media access" else "Nothing playing", h, h / 2 + u(5f), w - h - pad, 14f, fg, bold, glowIt = true)
                return
            }
            val s = min(w, h) * 0.22f
            note(pad + s * 0.5f, pad + s * 0.6f, s, fg)
            val y = h - pad - u(26f)
            text(if (!n.allowed) "Tap to enable" else "Nothing playing", pad, y, w - pad * 2, if (layout == "small") 17f else 20f, fg, bold, glowIt = true)
            text(if (!n.allowed) "media access for So Widget" else "Play music in any app", pad, y + u(20f), w - pad * 2, 13f, dim, medium)
        }

        // 1 · Classic (Now Playing #31)
        fun classicDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            background(tint)
            val pr = progress(n)
            when (layout) {
                "small" -> {
                    val a = min(w, h) * 0.36f
                    art(n.art, RectF(pad, pad, pad + a, pad + a), radius * 0.5f, tint ?: accent)
                    val btn = u(40f)
                    val ctl = soloButton(RectF(w - pad - btn, pad, w - pad, pad + btn), n.playing)
                    var y = h - pad - u(30f)
                    if (n.duration > 0) {
                        bar(pad, h - pad - u(4f), w - pad, u(4f), pr)
                        y -= u(8f)
                    }
                    text(n.title, pad, y, w - pad * 2, 16f, fg, bold, glowIt = true)
                    text(n.artist, pad, y + u(18f), w - pad * 2, 12.5f, dim, medium)
                    return ctl
                }
                "medium" -> {
                    val a = h - pad * 2
                    val ar = RectF(pad, pad, pad + a, pad + a)
                    art(n.art, ar, radius * 0.55f, tint ?: accent)
                    val x0 = ar.right + u(16f)
                    val x1 = w - pad
                    val tw = x1 - x0
                    eq(x1, pad + u(12f), u(12f), n.playing)
                    text(status(n), x0, pad + u(11f), tw - u(26f), 11.5f, dim, medium)
                    text(n.title, x0, pad + u(34f), tw, 18f, fg, bold, glowIt = true)
                    text(n.artist, x0, pad + u(53f), tw, 13.5f, dim, medium)
                    val ctl = RectF(x0 - u(6f), h - pad - u(40f), x1 + u(6f), h - pad)
                    if (n.duration > 0) bar(x0, ctl.top - u(12f), x1, u(4f), pr)
                    return circleRow(ctl, n.playing, plain = false)
                }
                else -> {
                    val ctlH = u(56f)
                    val a = min(w - pad * 2, h - pad * 2 - ctlH - u(96f))
                    val ar = RectF(pad, pad, pad + a, pad + a)
                    art(n.art, ar, radius * 0.6f, tint ?: accent)
                    if (a < w - pad * 2 - u(60f)) text(status(n), ar.right + u(16f), pad + u(12f), w - ar.right - u(16f) - pad, 12f, dim, medium)
                    var y = ar.bottom + u(30f)
                    text(n.title, pad, y, w - pad * 2 - u(30f), 22f, fg, bold, glowIt = true)
                    eq(w - pad, y, u(16f), n.playing)
                    y += u(22f)
                    text(n.artist, pad, y, w - pad * 2, 15f, dim, medium)
                    y += u(18f)
                    if (n.duration > 0) {
                        bar(pad, y, w - pad, u(5f), pr)
                        text(time(n.position), pad, y + u(20f), u(80f), 11f, dim, medium)
                        text("-" + time(n.duration - n.position), w - pad, y + u(20f), u(80f), 11f, dim, medium, align = 2)
                    }
                    return circleRow(RectF(pad, h - pad - ctlH, w - pad, h - pad), n.playing)
                }
            }
        }

        // 2 · Vinyl — the reference: sleeve on top, record peeking out, waveform, pill controls.
        fun vinylDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            background(null)
            val label = tint ?: hot
            val angle = (n.position / 1000f * 33f) % 360f
            val pr = progress(n)
            if (layout == "medium") {
                val a = h - pad * 2
                val r = a * 0.47f
                vinyl(pad + a * 0.78f, h / 2, r, label, angle)
                art(n.art, RectF(pad, pad, pad + a, pad + a), u(6f), label)
                val x0 = pad + a * 0.78f + r + u(14f)
                val x1 = w - pad
                val ctlH = u(38f)
                val ctl = RectF(x0, h - pad - ctlH, x1, h - pad)
                text(both(n), x0, pad + u(16f), x1 - x0, 15f, fg, medium, glowIt = true)
                waveform(RectF(x0, pad + u(28f), x1, ctl.top - u(10f)), pr, seed(n), u(2f), u(1.8f))
                return pillRow(ctl, n.playing)
            }
            val small = layout == "small"
            val ctlH = u(if (small) 32f else 44f)
            val ctlTop = h - pad - ctlH
            val titleY = ctlTop - u(if (small) 12f else 22f)
            val waveH = u(if (small) 16f else 40f)
            val waveBottom = titleY - u(if (small) 17f else 32f)
            val waveTop = waveBottom - waveH
            val zone = waveTop - u(if (small) 6f else 14f)
            val r = min((w - pad * 2) * 0.32f, zone * 0.44f)
            val sleeveBottom = zone - r * 0.55f
            vinyl(w / 2, sleeveBottom - r * 0.45f, r, label, angle)
            val sleeve = RectF(pad * 0.9f, pad * 0.6f - u(4f), w - pad * 0.9f, sleeveBottom)
            art(n.art, sleeve, u(4f), label, shadow = false)
            // Thin shadow under the sleeve edge.
            cv.drawRect(RectF(sleeve.left, sleeve.bottom, sleeve.right, sleeve.bottom + u(3f)), Paint().apply {
                shader = LinearGradient(0f, sleeve.bottom, 0f, sleeve.bottom + u(3f), Color.argb(90, 0, 0, 0), Color.TRANSPARENT, Shader.TileMode.CLAMP)
            })
            waveform(RectF(pad, waveTop, w - pad, waveBottom), pr, seed(n), u(if (small) 1.8f else 2.4f), u(if (small) 1.6f else 2.2f))
            text(both(n), w / 2, titleY, w - pad * 2, if (small) 13f else 20f, fg, regular, glowIt = true, align = 1)
            return pillRow(RectF(pad, ctlTop, w - pad, h - pad), n.playing)
        }

        // 3 · Cover — full-bleed artwork with glass controls.
        fun coverDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            background(tint)
            n.art?.let { cv.drawRect(full, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { shader = coverShader(it, full) }) }
            cv.drawRect(full, Paint().apply {
                shader = LinearGradient(0f, h * 0.2f, 0f, h, Color.TRANSPARENT, Color.argb(225, 0, 0, 0), Shader.TileMode.CLAMP)
            })
            val white = Color.WHITE
            val pr = progress(n)
            if (layout != "small" && n.app.isNotEmpty()) {
                val tpaint = tp(11f, white, medium, false)
                val tw = tpaint.measureText(n.app) + u(22f)
                val chip = RectF(pad, pad, pad + tw, pad + u(22f))
                cv.drawRoundRect(chip, u(11f), u(11f), p(Color.argb(90, 0, 0, 0)))
                cv.drawCircle(chip.left + u(9f), chip.centerY(), u(3f), p(if (n.playing) hot else Color.GRAY))
                text(n.app, chip.left + u(16f), chip.centerY() + u(4f), tw, 11f, white, medium)
            }
            return when (layout) {
                "small" -> {
                    val b = u(38f)
                    val ctl = RectF(w - pad - b, pad, w - pad, pad + b)
                    cv.drawCircle(ctl.centerX(), ctl.centerY(), b / 2, p(Color.argb(110, 0, 0, 0)))
                    toggleIcon(ctl.centerX(), ctl.centerY(), b * 0.42f, white, n.playing)
                    text(n.title, pad, h - pad - u(22f), w - pad * 2, 15f, white, bold)
                    text(n.artist, pad, h - pad - u(6f), w - pad * 2, 12f, Color.argb(190, 255, 255, 255), medium)
                    if (n.duration > 0) bar(pad, h - u(5f), w - pad, u(2.5f), pr, white, knob = false)
                    Controls(toggle = ctl)
                }
                "medium" -> {
                    val ctlW = u(140f)
                    val ctl = RectF(w - pad - ctlW, h - pad - u(40f), w - pad, h - pad)
                    text(n.title, pad, h - pad - u(28f), w - pad * 2 - ctlW - u(8f), 19f, white, bold)
                    text(n.artist, pad, h - pad - u(9f), w - pad * 2 - ctlW - u(8f), 13f, Color.argb(190, 255, 255, 255), medium)
                    if (n.duration > 0) bar(pad, h - u(6f), w - pad, u(3f), pr, white, knob = false)
                    glassRowOnImage(ctl, n.playing)
                }
                else -> {
                    val ctl = RectF(pad, h - pad - u(48f), w - pad, h - pad)
                    text(n.title, pad, ctl.top - u(48f), w - pad * 2, 24f, white, bold)
                    text(n.artist, pad, ctl.top - u(28f), w - pad * 2, 15f, Color.argb(190, 255, 255, 255), medium)
                    if (n.duration > 0) bar(pad, ctl.top - u(14f), w - pad, u(3f), pr, white, knob = false)
                    glassRowOnImage(ctl, n.playing)
                }
            }
        }

        fun glassRowOnImage(r: RectF, playing: Boolean): Controls {
            val b = min(r.height(), u(44f))
            val cy = r.centerY()
            val xs = listOf(r.left + r.width() / 6, r.centerX(), r.right - r.width() / 6)
            cv.drawCircle(xs[0], cy, b / 2, p(Color.argb(80, 255, 255, 255)))
            cv.drawCircle(xs[2], cy, b / 2, p(Color.argb(80, 255, 255, 255)))
            cv.drawCircle(xs[1], cy, b / 2, p(Color.WHITE))
            skipIcon(xs[0], cy, b * 0.38f, Color.WHITE, false)
            skipIcon(xs[2], cy, b * 0.38f, Color.WHITE, true)
            toggleIcon(xs[1], cy, b * 0.42f, Color.BLACK, playing)
            val third = r.width() / 3
            return Controls(
                RectF(r.left, r.top, r.left + third, r.bottom),
                RectF(r.left + third, r.top, r.right - third, r.bottom),
                RectF(r.right - third, r.top, r.right, r.bottom),
            )
        }

        // 4 · Wave — the waveform is the hero.
        fun waveDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            background(tint)
            val pr = progress(n)
            if (layout == "small") {
                text(n.title, pad, pad + u(14f), w - pad * 2, 15f, fg, bold, glowIt = true)
                text(n.artist, pad, pad + u(31f), w - pad * 2, 12f, dim, medium)
                val b = u(38f)
                val ctl = RectF(w - pad - b, h - pad - b, w - pad, h - pad)
                waveform(RectF(pad, pad + u(42f), w - pad, ctl.top - u(8f)), pr, seed(n), u(2f), u(1.8f))
                text(time(n.position), pad, h - pad - u(12f), u(70f), 12f, dim, medium)
                return soloButton(ctl, n.playing)
            }
            val thumb = u(if (layout == "large") 52f else 38f)
            art(n.art, RectF(pad, pad, pad + thumb, pad + thumb), u(10f), tint ?: hot)
            val tx = pad + thumb + u(12f)
            text(n.title, tx, pad + thumb * 0.45f, w - tx - pad, if (layout == "large") 19f else 16f, fg, bold, glowIt = true)
            text(n.artist, tx, pad + thumb * 0.45f + u(18f), w - tx - pad, 13f, dim, medium)
            val ctlH = u(if (layout == "large") 52f else 38f)
            val ctl = RectF(pad, h - pad - ctlH, w - pad, h - pad)
            val timeY = ctl.top - u(10f)
            val waveRect = RectF(pad, pad + thumb + u(10f), w - pad, timeY - u(16f))
            waveform(waveRect, pr, seed(n), u(if (layout == "large") 3.2f else 2.4f), u(if (layout == "large") 2.6f else 2f))
            text(time(n.position), pad, timeY, u(70f), 11f, dim, medium)
            text(time(n.duration), w - pad, timeY, u(70f), 11f, dim, medium, align = 2)
            return if (layout == "large") circleRow(ctl, n.playing) else circleRow(RectF(w * 0.25f, ctl.top, w * 0.75f, ctl.bottom), n.playing)
        }

        // 5 · Disc — round artwork with a progress ring.
        fun discDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            background(tint)
            val pr = progress(n)
            val stroke = u(if (layout == "large") 5f else 4f)
            if (layout == "medium") {
                val r = (h - pad * 2) / 2 - stroke
                val cx = pad + r + stroke
                val cy = h / 2
                artCircle(n.art, cx, cy, r - stroke * 1.6f, noteIcon = false)
                ring(cx, cy, r, stroke, pr)
                val badge = r * 0.55f
                cv.drawCircle(cx, cy, badge / 2, p(Color.argb(120, 0, 0, 0)))
                toggleIcon(cx, cy, badge * 0.45f, Color.WHITE, n.playing)
                val x0 = cx + r + u(18f)
                val x1 = w - pad
                text(status(n), x0, pad + u(16f), x1 - x0, 11.5f, dim, medium)
                text(n.title, x0, pad + u(40f), x1 - x0, 18f, fg, bold, glowIt = true)
                text(n.artist, x0, pad + u(59f), x1 - x0, 13.5f, dim, medium)
                val row = RectF(x0 - u(4f), h - pad - u(36f), x1, h - pad)
                skipIcon(row.left + u(18f), row.centerY(), u(16f), fg, false)
                skipIcon(row.left + u(70f), row.centerY(), u(16f), fg, true)
                if (n.duration > 0) text("${time(n.position)} / ${time(n.duration)}", x1, row.centerY() + u(4f), u(110f), 11f, dim, medium, align = 2)
                return Controls(
                    RectF(row.left, row.top, row.left + u(44f), row.bottom),
                    RectF(cx - r, cy - r, cx + r, cy + r),
                    RectF(row.left + u(48f), row.top, row.left + u(92f), row.bottom),
                )
            }
            val small = layout == "small"
            val textH = u(if (small) 38f else 58f)
            val side = u(if (small) 0f else 44f)
            val r = min((w - pad * 2 - side * 2) / 2, (h - pad * 2 - textH) / 2) - stroke
            val cx = w / 2
            val cy = pad + stroke + r
            artCircle(n.art, cx, cy, r - stroke * 1.6f, noteIcon = false)
            ring(cx, cy, r, stroke, pr)
            val badge = r * 0.42f
            cv.drawCircle(cx, cy, badge / 2, p(Color.argb(120, 0, 0, 0)))
            toggleIcon(cx, cy, badge * 0.45f, Color.WHITE, n.playing)
            val ty = cy + r + stroke + u(if (small) 18f else 30f)
            text(n.title, cx, ty, w - pad * 2, if (small) 14f else 20f, fg, bold, glowIt = true, align = 1)
            text(n.artist, cx, ty + u(if (small) 15f else 22f), w - pad * 2, if (small) 11f else 14f, dim, medium, align = 1)
            val toggle = RectF(cx - r, cy - r, cx + r, cy + r)
            if (small) return Controls(toggle = toggle)
            val prevC = (cx - r - stroke) / 2 + pad / 2
            val nextC = w - prevC
            skipIcon(prevC, cy, u(18f), fg, false)
            skipIcon(nextC, cy, u(18f), fg, true)
            return Controls(
                RectF(0f, cy - u(30f), cx - r - stroke, cy + u(30f)),
                toggle,
                RectF(cx + r + stroke, cy - u(30f), w, cy + u(30f)),
            )
        }

        // 6 · Type — editorial text, like the weather sentence widget.
        fun typeDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            background(null)
            val big = when (layout) {
                "small" -> 19f
                "medium" -> 22f
                else -> 32f
            }
            val line = u(big * 1.18f)
            var y = pad + u(big * 0.95f)
            val maxW = w - pad * 2
            text(if (n.playing) "now playing" else "paused", pad, y, maxW, big, dim, bold)
            cv.drawCircle(w - pad - u(5f), y - u(big * 0.32f), u(4.5f), p(if (n.playing) hot else alpha(fg, 0.3f)))
            y += line
            text(n.title, pad, y, maxW, big, fg, bold, glowIt = true)
            y += line
            val byW = tp(big, dim, bold, false).measureText("by ")
            text("by ", pad, y, maxW, big, dim, bold)
            text(n.artist.ifEmpty { "unknown" }, pad + byW, y, maxW - byW, big, fg, bold, glowIt = true)
            if (layout != "medium" || h > u(160f)) {
                y += line
                if (n.duration > 0 && y < h - pad - u(44f)) {
                    val tW = tp(big, fg, bold, false).measureText(time(n.position) + " ")
                    text(time(n.position) + " ", pad, y, maxW, big, fg, bold)
                    text("of " + time(n.duration), pad + tW, y, maxW - tW, big, dim, bold)
                }
            }
            val ic = u(if (layout == "large") 30f else 24f)
            return if (layout == "small") {
                val ctl = RectF(w - pad - ic * 1.6f, h - pad - ic * 1.6f, w - pad, h - pad)
                toggleIcon(ctl.centerX(), ctl.centerY(), ic * 0.8f, fg, n.playing)
                Controls(toggle = ctl)
            } else {
                val rowW = ic * 6f
                val row = RectF(w - pad - rowW, h - pad - ic * 1.6f, w - pad, h - pad)
                if (n.duration > 0) bar(pad, row.centerY() - u(1.5f), row.left - u(16f), u(3f), progress(n), hot, knob = false)
                circleRow(row, n.playing, plain = true)
            }
        }

        // 7 · Capsule — blurred artwork with a floating glass capsule.
        fun capsuleDesign(layout: String, n: SoMedia.Now, tint: Int?): Controls {
            blurredArt(n.art, tint)
            val white = Color.WHITE
            val capH = u(if (layout == "small") 48f else 60f)
            val cap = RectF(pad * 0.8f, h - pad * 0.8f - capH, w - pad * 0.8f, h - pad * 0.8f)
            if (layout == "large" || layout == "medium") {
                val area = RectF(pad, pad, w - pad, cap.top - u(12f))
                val a = min(area.width(), area.height())
                val ar = if (layout == "large") RectF(w / 2 - a / 2, area.top, w / 2 + a / 2, area.top + a)
                else RectF(pad, area.top, pad + a, area.top + a)
                art(n.art, ar, u(14f), tint ?: hot)
                if (layout == "medium") {
                    val x0 = ar.right + u(14f)
                    text(status(n), x0, ar.top + u(14f), w - x0 - pad, 11.5f, Color.argb(200, 255, 255, 255), medium)
                    text(n.artist, x0, ar.top + u(34f), w - x0 - pad, 15f, white, bold)
                    if (n.duration > 0) text("${time(n.position)} / ${time(n.duration)}", x0, ar.bottom, w - x0 - pad, 11f, Color.argb(180, 255, 255, 255), medium)
                }
            } else {
                art(n.art, RectF(pad, pad, pad + u(56f), pad + u(56f)), u(12f), tint ?: hot)
            }
            cv.drawRoundRect(cap, capH / 2, capH / 2, p(Color.argb(150, 18, 18, 20)))
            cv.drawRoundRect(cap, capH / 2, capH / 2, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = u(0.8f)
                color = Color.argb(40, 255, 255, 255)
            })
            val inset = u(6f)
            val btn = capH - inset * 2
            val toggle = RectF(cap.right - inset - btn, cap.top + inset, cap.right - inset, cap.bottom - inset)
            glowCircle(toggle.centerX(), toggle.centerY(), btn / 2, white)
            cv.drawCircle(toggle.centerX(), toggle.centerY(), btn / 2, p(white))
            toggleIcon(toggle.centerX(), toggle.centerY(), btn * 0.42f, Color.BLACK, n.playing)
            val tx = cap.left + capH * 0.42f
            val tw = toggle.left - tx - u(8f)
            text(n.title, tx, cap.centerY() - u(2f), tw, if (layout == "small") 13f else 15f, white, bold)
            text(n.artist, tx, cap.centerY() + u(14f), tw, 11f, Color.argb(180, 255, 255, 255), medium)
            if (n.duration > 0) {
                val pr = progress(n)
                val l = cap.left + capH * 0.42f
                cv.drawRect(RectF(l, cap.bottom - u(4f), l + (toggle.left - u(8f) - l) * pr, cap.bottom - u(2.5f)), p(hot))
            }
            // Equalizer dot at the capsule start.
            cv.drawCircle(cap.left + capH * 0.22f, cap.centerY(), u(4f), p(if (n.playing) hot else Color.GRAY))
            return Controls(toggle = toggle)
        }
    }
}

/** Handles ⏮ ⏯ ⏭ taps on native media widgets. */
class SoMediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        try {
            SoMedia.control(context, intent.getStringExtra("a"))
        } catch (_: Exception) {
        }
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                SoNowPlaying.updateAll(context)
            } finally {
                pending.finish()
            }
        }, 350)
    }
}
