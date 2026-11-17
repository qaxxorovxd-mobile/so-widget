package uz.qaxxorov.so_widget

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import es.antonborri.home_widget.HomeWidgetPlugin
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Chained one-shot work: request the next refresh in five minutes, subject to OS quotas/Doze. */
class SoRefreshJob : JobService() {
    companion object {
        const val JOB_ID = 5305
        const val INTERVAL = 5 * 60 * 1000L
        private var running = false
        private var mediaPending = false
        fun hasWidget(context: Context, id: String? = null): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val prefs = HomeWidgetPlugin.getData(context)
            return SoHome.providers.values.any { cls ->
                manager.getAppWidgetIds(ComponentName(context, cls)).any { wid ->
                    id == null || prefs.getString(SoHome.instKey(wid), null) == id
                }
            }
        }
        fun enqueue(context: Context, immediate: Boolean = false) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (!hasWidget(context)) { scheduler.cancel(JOB_ID); return }
            if (running) { if (immediate) mediaPending = true; return }
            if (!immediate && scheduler.allPendingJobs.any { it.id == JOB_ID }) return
            scheduler.schedule(JobInfo.Builder(JOB_ID, ComponentName(context, SoRefreshJob::class.java))
                .setMinimumLatency(if (immediate) 0 else INTERVAL)
                .setPersisted(true)
                .build())
        }
    }
    private val handler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var detachMedia: (() -> Unit)? = null
    private var detachHome: (() -> Unit)? = null
    private var active: JobParameters? = null
    private val timeout = Runnable { finishWork(false) }

    override fun onStartJob(params: JobParameters): Boolean {
        if (!hasWidget(this)) return false
        running = true
        active = params
        handler.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val worker = FlutterEngine(applicationContext)
                engine = worker
                detachMedia = SoMedia.attach(applicationContext, worker.dartExecutor.binaryMessenger)
                detachHome = SoHome.attach(applicationContext, worker.dartExecutor.binaryMessenger, listen = false)
                MethodChannel(worker.dartExecutor.binaryMessenger, "so_widget/background").setMethodCallHandler { call, result ->
                    if (call.method == "complete") {
                        val success = call.argument<Boolean>("success") == true
                        result.success(null)
                        handler.post { finishWork(success) }
                    } else result.notImplemented()
                }
                handler.postDelayed(timeout, 110_000)
                worker.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "widgetRefreshMain"))
            } catch (_: Exception) { finishWork(false) }
        }
        return true
    }
    private fun release() {
        handler.removeCallbacks(timeout)
        detachMedia?.invoke()
        detachMedia = null
        detachHome?.invoke()
        detachHome = null
        engine?.destroy()
        engine = null
        running = false
    }
    private fun finishWork(success: Boolean) {
        val params = active ?: return
        active = null
        HomeWidgetPlugin.getData(this).edit()
            .putLong("so_refresh_attempt", System.currentTimeMillis())
            .putBoolean("so_refresh_ok", success).apply()
        release()
        jobFinished(params, false)
        val immediate = mediaPending
        mediaPending = false
        // Give JobScheduler time to retire the old job before rescheduling its id.
        handler.postDelayed({
            (getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB_ID)
            enqueue(applicationContext, immediate)
        }, 500)
    }
    override fun onStopJob(params: JobParameters): Boolean {
        active = null
        release()
        return hasWidget(this)
    }
}
