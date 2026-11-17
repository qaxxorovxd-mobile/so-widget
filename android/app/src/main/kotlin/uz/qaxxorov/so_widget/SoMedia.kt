package uz.qaxxorov.so_widget

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.service.notification.NotificationListenerService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

object SoMedia {
    val listeners = mutableSetOf<() -> Unit>()
    private var lastArt: Bitmap? = null
    private var artBytes: ByteArray? = null
    fun component(context: Context) = ComponentName(context, SoMediaListener::class.java)
    fun allowed(context: Context): Boolean =
        Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            ?.split(':')?.any { ComponentName.unflattenFromString(it) == component(context) } == true

    fun sessions(context: Context): List<MediaController> = try {
        if (allowed(context)) (context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager)
            .getActiveSessions(component(context)) else emptyList()
    } catch (_: SecurityException) { emptyList() }

    fun playing(c: MediaController) = c.playbackState?.state in listOf(
        PlaybackState.STATE_PLAYING, PlaybackState.STATE_BUFFERING, PlaybackState.STATE_CONNECTING)

    /** Prefer a playing session; otherwise the most recent one that has a title. */
    fun current(context: Context): MediaController? {
        val all = sessions(context)
        return all.firstOrNull { playing(it) }
            ?: all.firstOrNull { !it.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE).isNullOrEmpty() }
            ?: all.firstOrNull()
    }

    /** Everything the native Now Playing widget needs, read straight from the media session. */
    data class Now(
        val allowed: Boolean,
        val controller: MediaController?,
        val title: String,
        val artist: String,
        val app: String,
        val playing: Boolean,
        val position: Long,
        val duration: Long,
        val art: Bitmap?,
    ) {
        val hasTrack get() = allowed && title.isNotEmpty()
    }

    fun now(context: Context): Now {
        val ok = allowed(context)
        val c = if (ok) current(context) else null
        val meta = c?.metadata
        val state = c?.playbackState
        val isPlaying = c != null && playing(c)
        val duration = meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val elapsed = if (isPlaying && state != null && state.lastPositionUpdateTime > 0)
            ((SystemClock.elapsedRealtime() - state.lastPositionUpdateTime) * state.playbackSpeed).toLong() else 0L
        var pos = ((state?.position ?: 0L) + elapsed).coerceAtLeast(0L)
        if (duration > 0) pos = pos.coerceAtMost(duration)
        val label = try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(c?.packageName ?: "", 0)).toString()
        } catch (_: Exception) { "" }
        return Now(
            allowed = ok,
            controller = c,
            title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: meta?.description?.title?.toString() ?: "",
            artist = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                ?: meta?.description?.subtitle?.toString() ?: "",
            app = label,
            playing = isPlaying,
            position = pos,
            duration = duration,
            art = meta?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: meta?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: meta?.description?.iconBitmap,
        )
    }

    fun control(context: Context, action: String?) {
        val c = current(context) ?: return
        when (action) {
            "toggle" -> if (playing(c)) c.transportControls.pause() else c.transportControls.play()
            "previous" -> c.transportControls.skipToPrevious()
            "next" -> c.transportControls.skipToNext()
        }
    }

    fun snapshot(context: Context): Map<String, Any?> {
        val controller = current(context)
        val meta = controller?.metadata
        val state = controller?.playbackState
        val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: meta?.description?.title?.toString()
        val duration = meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val isPlaying = controller != null && playing(controller)
        val elapsed = if (isPlaying && state != null && state.lastPositionUpdateTime > 0)
            ((SystemClock.elapsedRealtime() - state.lastPositionUpdateTime) * state.playbackSpeed).toLong() else 0L
        val position = ((state?.position ?: 0L) + elapsed).coerceAtLeast(0L)
        val artwork = meta?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: meta?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) ?: meta?.description?.iconBitmap
        if (artwork !== lastArt) {
            lastArt = artwork
            artBytes = artwork?.let {
                val scale = minOf(1.0, 384.0 / maxOf(it.width, it.height))
                val scaled = Bitmap.createScaledBitmap(it, maxOf(1, (it.width * scale).toInt()), maxOf(1, (it.height * scale).toInt()), true)
                val stream = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.PNG, 100, stream)
                if (scaled !== it) scaled.recycle()
                stream.toByteArray()
            }
        }
        return mapOf("allowed" to allowed(context), "title" to title,
            "artist" to (meta?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: meta?.description?.subtitle?.toString() ?: ""),
            "app" to controller?.packageName, "playing" to isPlaying,
            "duration" to duration, "position" to if (duration > 0) position.coerceAtMost(duration) else position,
            "artwork" to artBytes, "actions" to (state?.actions ?: 0L))
    }

    fun attach(context: Context, messenger: BinaryMessenger, events: Boolean = false): () -> Unit {
        val channel = MethodChannel(messenger, "so_widget/media")
        val listener: () -> Unit = { channel.invokeMethod("changed", null) }
        if (events) listeners.add(listener)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "snapshot" -> result.success(snapshot(context))
                    "permission" -> {
                        context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "control" -> {
                        val c = current(context)
                        when (call.argument<String>("action")) {
                            "toggle" -> if (c != null) { if (playing(c)) c.transportControls.pause() else c.transportControls.play() }
                            "previous" -> c?.transportControls?.skipToPrevious()
                            "next" -> c?.transportControls?.skipToNext()
                            "open" -> c?.sessionActivity?.send()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("media", e.message, null) }
        }
        return { listeners.remove(listener); channel.setMethodCallHandler(null) }
    }
}

/** Only media sessions are read. Notification text/content is never collected. */
class SoMediaListener : NotificationListenerService() {
    private val handler = Handler(Looper.getMainLooper())
    private val controllers = mutableListOf<MediaController>()
    private val changed = Runnable {
        SoMedia.listeners.toList().forEach { it() }
        // Native widget: redraw instantly, no Flutter engine needed.
        SoNowPlaying.updateAll(this)
    }
    private val screenOn = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = SoNowPlaying.updateAll(context)
    }
    private var screenRegistered = false
    private fun notifyChange() { handler.removeCallbacks(changed); handler.postDelayed(changed, 300) }
    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = notifyChange()
        override fun onPlaybackStateChanged(state: PlaybackState?) = notifyChange()
        override fun onSessionDestroyed() = observe()
    }
    private val sessionListener = MediaSessionManager.OnActiveSessionsChangedListener { observe() }
    private fun observe() {
        controllers.forEach { it.unregisterCallback(callback) }
        controllers.clear()
        controllers.addAll(SoMedia.sessions(this))
        controllers.forEach { it.registerCallback(callback, handler) }
        notifyChange()
    }
    override fun onListenerConnected() {
        super.onListenerConnected()
        try {
            (getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager)
                .addOnActiveSessionsChangedListener(sessionListener, SoMedia.component(this), handler)
        } catch (_: SecurityException) {}
        if (!screenRegistered) {
            try {
                registerReceiver(screenOn, android.content.IntentFilter(Intent.ACTION_SCREEN_ON))
                screenRegistered = true
            } catch (_: Exception) {}
        }
        observe()
    }
    override fun onListenerDisconnected() {
        controllers.forEach { it.unregisterCallback(callback) }
        controllers.clear()
        (getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager).removeOnActiveSessionsChangedListener(sessionListener)
        notifyChange()
        super.onListenerDisconnected()
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (screenRegistered) {
            try { unregisterReceiver(screenOn) } catch (_: Exception) {}
            screenRegistered = false
        }
        controllers.forEach { it.unregisterCallback(callback) }
        (getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager).removeOnActiveSessionsChangedListener(sessionListener)
        super.onDestroy()
    }
}
