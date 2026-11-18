package uz.qaxxorov.so_widget

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ENGINE = "so_main"
    }

    /**
     * Keeps one engine across activity re-creations. Setting a wallpaper on Android 12+ changes the
     * Material You palette, which makes the system re-create the activity; with a cached engine the
     * app keeps its screens and state instead of restarting.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE)?.let { return it }
        val engine = FlutterEngine(context.applicationContext)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        cache.put(ENGINE, engine)
        return engine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onDestroy() {
        val closing = isFinishing && !isChangingConfigurations
        super.onDestroy()
        if (closing) {
            val cache = FlutterEngineCache.getInstance()
            cache.get(ENGINE)?.destroy()
            cache.remove(ENGINE)
        }
    }

    private var detachMedia: (() -> Unit)? = null
    private var detachHome: (() -> Unit)? = null
    private var detachDevice: (() -> Unit)? = null
    private var detachWallpaper: (() -> Unit)? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        detachMedia = SoMedia.attach(this, flutterEngine.dartExecutor.binaryMessenger, events = true)
        SoPermissions.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        detachHome = SoHome.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger, listen = true)
        detachDevice = SoDevices.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        SoDevices.updateAll(this)
        detachWallpaper = SoWallpaper.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        // Some phones (Xiaomi, Oppo…) unbind the listener after the app is killed; ask the system to rebind it.
        try {
            if (SoMedia.allowed(this) && android.os.Build.VERSION.SDK_INT >= 24) {
                android.service.notification.NotificationListenerService.requestRebind(SoMedia.component(this))
            }
        } catch (_: Exception) {}
        SoNowPlaying.updateAll(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "so_widget/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleRefresh" -> {
                    SoRefreshJob.enqueue(this)
                    result.success(null)
                }
                "pin" -> {
                    val slot = call.argument<String>("slot") ?: ""
                    val id = call.argument<String>("id") ?: ""
                    result.success(try { requestSoPin(this, slot, id) } catch (e: Exception) { false })
                }
                "refresh" -> {
                    val wid = call.argument<Int>("wid")
                    if (wid != null) SoHome.refresh(this, wid)
                    result.success(null)
                }
                "mediaPreview" -> {
                    val id = call.argument<String>("id") ?: SoNowPlaying.ID
                    val w = call.argument<Int>("w") ?: 170
                    val h = call.argument<Int>("h") ?: 170
                    val style = call.argument<String>("style")
                    Thread {
                        val bytes = try {
                            if (SoDevices.isDevice(id)) SoDevices.preview(applicationContext, id, w, h, style)
                            else SoNowPlaying.preview(applicationContext, id, w, h, style)
                        } catch (e: Exception) { null }
                        runOnUiThread { result.success(bytes) }
                    }.start()
                }
                "nowPlaying" -> {
                    SoNowPlaying.updateAll(this)
                    result.success(null)
                }
                "moveToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        detachMedia?.invoke()
        detachMedia = null
        detachHome?.invoke()
        detachHome = null
        detachDevice?.invoke()
        detachDevice = null
        detachWallpaper?.invoke()
        detachWallpaper = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
