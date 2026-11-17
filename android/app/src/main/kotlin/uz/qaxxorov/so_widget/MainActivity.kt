package uz.qaxxorov.so_widget

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var detachMedia: (() -> Unit)? = null
    private var detachHome: (() -> Unit)? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        detachMedia = SoMedia.attach(this, flutterEngine.dartExecutor.binaryMessenger, events = true)
        SoPermissions.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        detachHome = SoHome.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger, listen = true)
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
                        val bytes = try { SoNowPlaying.preview(applicationContext, id, w, h, style) } catch (e: Exception) { null }
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
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
