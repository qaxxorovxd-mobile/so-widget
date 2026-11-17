package uz.qaxxorov.so_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Every home-screen instance (appWidgetId) is bound to its own So Widget:
 *   so_inst_<appWidgetId>  -> So Widget id (e.g. "power")
 *   so_img_<id>_<slot>     -> path of the image Flutter rendered for that widget + size
 */
object SoHome {
    val providers = mapOf(
        "small" to SoSmallWidget::class.java,
        "medium" to SoMediumWidget::class.java,
        "large" to SoLargeWidget::class.java,
    )

    fun instKey(wid: Int) = "so_inst_$wid"

    fun imgKey(id: String, slot: String) = "so_img_${id}_$slot"

    /** Called when a widget is resized while the app is running. */
    val resizeListeners = mutableSetOf<() -> Unit>()

    /** Real size of every placed widget in dp: appWidgetId -> [width, height] (portrait). */
    fun sizes(context: Context): Map<String, List<Int>> {
        val mgr = AppWidgetManager.getInstance(context)
        val out = mutableMapOf<String, List<Int>>()
        for (cls in providers.values) {
            for (wid in mgr.getAppWidgetIds(ComponentName(context, cls))) {
                val o = mgr.getAppWidgetOptions(wid)
                val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
                if (w > 0 && h > 0) out[wid.toString()] = listOf(w, h)
            }
        }
        return out
    }

    /** Channel shared by the app engine and the background refresh engine. */
    fun attach(context: Context, messenger: io.flutter.plugin.common.BinaryMessenger, listen: Boolean): () -> Unit {
        val channel = io.flutter.plugin.common.MethodChannel(messenger, "so_widget/home")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sizes" -> result.success(sizes(context))
                "density" -> result.success(context.resources.displayMetrics.density.toDouble())
                else -> result.notImplemented()
            }
        }
        val l: () -> Unit = { channel.invokeMethod("resized", null) }
        if (listen) resizeListeners.add(l)
        return {
            resizeListeners.remove(l)
            channel.setMethodCallHandler(null)
        }
    }

    fun slotOf(context: Context, wid: Int): String? {
        val cls = AppWidgetManager.getInstance(context).getAppWidgetInfo(wid)?.provider?.className ?: return null
        return providers.entries.firstOrNull { it.value.name == cls }?.key
    }

    fun assign(context: Context, wid: Int, id: String) {
        HomeWidgetPlugin.getData(context).edit().putString(instKey(wid), id).commit()
        refresh(context, wid)
        SoRefreshJob.enqueue(context, immediate = true)
    }

    fun refresh(context: Context, wid: Int) {
        val slot = slotOf(context, wid) ?: return
        render(context, AppWidgetManager.getInstance(context), wid, HomeWidgetPlugin.getData(context), slot)
    }

    fun render(context: Context, mgr: AppWidgetManager, wid: Int, prefs: SharedPreferences, slot: String) {
        val id = prefs.getString(instKey(wid), null)
        if (SoNowPlaying.isMedia(id)) {
            SoNowPlaying.render(context, mgr, wid, slot, id!!)
            return
        }
        // Each instance has its own image drawn at its real size; fall back to the older per-size image.
        val path = id?.let {
            prefs.getString("so_img_w$wid", null)?.takeIf { p -> File(p).exists() }
                ?: prefs.getString(imgKey(it, slot), null)
        }
        val bitmap = path?.let { p -> if (File(p).exists()) BitmapFactory.decodeFile(p) else null }
        val views = RemoteViews(context.packageName, R.layout.so_widget)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.so_image, bitmap)
            views.setViewVisibility(R.id.so_image, View.VISIBLE)
            views.setViewVisibility(R.id.so_empty, View.GONE)
        } else {
            views.setViewVisibility(R.id.so_image, View.GONE)
            views.setViewVisibility(R.id.so_empty, View.VISIBLE)
            views.setTextViewText(
                R.id.so_empty,
                context.getString(if (id == null) R.string.so_widget_choose else R.string.so_widget_empty),
            )
        }
        val click = if (id == null) {
            val i = Intent(context, SoConfigActivity::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid)
                .setData(Uri.parse("sowidget://pick/$wid"))
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
            PendingIntent.getActivity(context, wid, i, flags)
        } else {
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("sowidget://open?id=$id&wid=$wid"),
            )
        }
        views.setOnClickPendingIntent(R.id.so_root, click)
        mgr.updateAppWidget(wid, views)
    }
}

abstract class SoBaseWidget(private val slot: String) : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (wid in appWidgetIds) SoHome.render(context, appWidgetManager, wid, widgetData, slot)
        SoRefreshJob.enqueue(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // Resized on the home screen: media widgets redraw natively right now; the others are
        // redrawn by Flutter at the new size (app engine if running, otherwise the background job).
        SoHome.render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context), slot)
        if (!SoNowPlaying.isMedia(HomeWidgetPlugin.getData(context).getString(SoHome.instKey(appWidgetId), null))) {
            if (SoHome.resizeListeners.isNotEmpty()) {
                SoHome.resizeListeners.toList().forEach { it() }
            } else {
                SoRefreshJob.enqueue(context, immediate = true)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val e = HomeWidgetPlugin.getData(context).edit()
        for (wid in appWidgetIds) e.remove(SoHome.instKey(wid))
        e.apply()
        SoRefreshJob.enqueue(context)
    }
}

class SoSmallWidget : SoBaseWidget("small")

class SoMediumWidget : SoBaseWidget("medium")

class SoLargeWidget : SoBaseWidget("large")

/** Receives the new appWidgetId after a pin request made from inside the app. */
class SoPinReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val wid = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val id = intent.getStringExtra("so_id") ?: return
        if (wid == AppWidgetManager.INVALID_APPWIDGET_ID) return
        SoHome.assign(context, wid, id)
    }
}

fun requestSoPin(context: Context, slot: String, id: String): Boolean {
    if (Build.VERSION.SDK_INT < 26) return false
    val mgr = context.getSystemService(AppWidgetManager::class.java) ?: return false
    if (!mgr.isRequestPinAppWidgetSupported) return false
    val cls = SoHome.providers[slot] ?: return false
    val cb = Intent(context, SoPinReceiver::class.java).putExtra("so_id", id).putExtra("slot", slot)
    var flags = PendingIntent.FLAG_UPDATE_CURRENT
    if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
    val pi = PendingIntent.getBroadcast(context, (slot + id).hashCode(), cb, flags)
    return mgr.requestPinAppWidget(ComponentName(context, cls), null, pi)
}
