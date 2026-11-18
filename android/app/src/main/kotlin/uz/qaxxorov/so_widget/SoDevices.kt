package uz.qaxxorov.so_widget

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.location.LocationManager
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.os.SystemClock
import android.provider.Settings
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

/**
 * Device manager widgets, drawn natively and live: Bluetooth (one-tap connect), Controls,
 * Batteries and Storage. Also serves real device stats (RAM, storage, steps…) to Flutter.
 */
object SoDevices {
    val IDS = setOf("d_bluetooth", "d_controls", "d_batteries", "d_storage")

    fun isDevice(id: String?) = id != null && id in IDS

    /** CupertinoIcons code points (the font ships inside the Flutter assets). */
    object G {
        const val BT = 0xf116
        const val HEADPHONES = 0xf6bb
        const val SPEAKER = 0xf3ba
        const val CAR = 0xf2c1
        const val WATCH = 0xf403
        const val PHONE = 0xf8cf
        const val LAPTOP = 0xf8cd
        const val KEYBOARD = 0xf6d1
        const val GAMEPAD = 0xf43b
        const val PRINTER = 0xf787
        const val TV = 0xf884
        const val WIFI = 0xf89b
        const val WIFI_OFF = 0xf89d
        const val TORCH = 0xf6de
        const val TORCH_OFF = 0xf6e0
        const val VIBRATE = 0xf894
        const val MUTE = 0xf3b9
        const val CELL = 0xf4dc
        const val SAVER = 0xf6d5
        const val LOCATION = 0xf6f1
        const val LOCATION_OFF = 0xf6f7
        const val MOON = 0xf719
        const val HOTSPOT = 0xf757
        const val BOLT = 0xf598
        const val BATTERY = 0xf113
        const val STORAGE = 0xf4e2
        const val CHIP = 0xf61d
        const val PLUS = 0xf489
        const val GEAR = 0xf43d
    }

    const val G_CHEVRON_LEFT = 0xf3d2
    const val G_CHEVRON_RIGHT = 0xf3d3

    private var iconFont: Typeface? = null

    fun icons(c: Context): Typeface? {
        iconFont?.let { return it }
        iconFont = try {
            Typeface.createFromAsset(c.assets, "flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf")
        } catch (_: Exception) {
            null
        }
        return iconFont
    }

    // ───────────────────────── data ─────────────────────────

    data class Bt(val name: String, val address: String, val icon: Int, val connected: Boolean, val battery: Int)

    data class BtState(val permitted: Boolean, val available: Boolean, val enabled: Boolean, val devices: List<Bt>)

    fun hasBtPermission(c: Context) =
        Build.VERSION.SDK_INT < 31 || c.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    fun adapter(c: Context): BluetoothAdapter? = c.getSystemService(BluetoothManager::class.java)?.adapter

    fun bluetooth(c: Context): BtState {
        val a = adapter(c) ?: return BtState(true, false, false, emptyList())
        val enabled = try { a.isEnabled } catch (_: SecurityException) { false }
        if (!hasBtPermission(c)) return BtState(false, true, enabled, emptyList())
        if (!enabled) return BtState(true, true, false, emptyList())
        val bonded = try { a.bondedDevices?.toList() ?: emptyList() } catch (_: SecurityException) { emptyList() }
        val list = bonded.map { d ->
            val name = try {
                (if (Build.VERSION.SDK_INT >= 30) d.alias else null) ?: d.name ?: d.address
            } catch (_: SecurityException) { d.address }
            Bt(name, d.address, iconFor(d), isConnected(d), batteryOf(d))
        }
        return BtState(true, true, true, list.sortedWith(compareByDescending<Bt> { it.connected }.thenBy { it.name.lowercase() }))
    }

    fun isConnected(d: BluetoothDevice) = try {
        d.javaClass.getMethod("isConnected").invoke(d) as Boolean
    } catch (_: Throwable) { false }

    fun batteryOf(d: BluetoothDevice) = try {
        d.javaClass.getMethod("getBatteryLevel").invoke(d) as Int
    } catch (_: Throwable) { -1 }

    private fun iconFor(d: BluetoothDevice): Int = try {
        val cls = d.bluetoothClass
        when {
            cls == null -> G.BT
            cls.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_CAR_AUDIO -> G.CAR
            cls.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_LOUDSPEAKER -> G.SPEAKER
            cls.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_VIDEO_DISPLAY_AND_LOUDSPEAKER -> G.TV
            cls.majorDeviceClass == BluetoothClass.Device.Major.AUDIO_VIDEO -> G.HEADPHONES
            cls.majorDeviceClass == BluetoothClass.Device.Major.WEARABLE -> G.WATCH
            cls.majorDeviceClass == BluetoothClass.Device.Major.PHONE -> G.PHONE
            cls.majorDeviceClass == BluetoothClass.Device.Major.COMPUTER -> G.LAPTOP
            cls.deviceClass == BluetoothClass.Device.PERIPHERAL_KEYBOARD -> G.KEYBOARD
            cls.majorDeviceClass == BluetoothClass.Device.Major.PERIPHERAL -> G.GAMEPAD
            cls.majorDeviceClass == BluetoothClass.Device.Major.IMAGING -> G.PRINTER
            else -> G.BT
        }
    } catch (_: Throwable) { G.BT }

    data class Phone(val level: Int, val charging: Boolean, val tempC: Float)

    fun phone(c: Context): Phone {
        val i = c.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val status = i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val temp = (i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10f
        val pct = if (level >= 0 && scale > 0) level * 100 / scale else -1
        return Phone(pct, status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL, temp)
    }

    data class Storage(val total: Long, val free: Long, val ramTotal: Long, val ramFree: Long)

    fun storage(c: Context): Storage {
        val s = try { StatFs(Environment.getDataDirectory().path) } catch (_: Exception) { null }
        val mi = ActivityManager.MemoryInfo()
        try { c.getSystemService(ActivityManager::class.java)?.getMemoryInfo(mi) } catch (_: Exception) {}
        return Storage(s?.totalBytes ?: 0, s?.availableBytes ?: 0, mi.totalMem, mi.availMem)
    }

    // Torch has no getter; track it with a callback.
    @Volatile var torchOn = false
    private var torchRegistered = false
    private val main = Handler(Looper.getMainLooper())

    fun ensureCallbacks(c: Context) {
        if (torchRegistered) return
        try {
            c.getSystemService(CameraManager::class.java)?.registerTorchCallback(object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    if (torchOn != enabled) {
                        torchOn = enabled
                        updateAll(c.applicationContext)
                    }
                }
            }, main)
            torchRegistered = true
        } catch (_: Exception) {}
    }

    fun toggleTorch(c: Context) {
        val cm = c.getSystemService(CameraManager::class.java) ?: return
        try {
            val id = cm.cameraIdList.firstOrNull {
                cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            } ?: return
            cm.setTorchMode(id, !torchOn)
            torchOn = !torchOn
        } catch (_: Exception) {}
    }

    fun cycleSound(c: Context) {
        val am = c.getSystemService(AudioManager::class.java) ?: return
        try {
            am.ringerMode = if (am.ringerMode == AudioManager.RINGER_MODE_NORMAL) AudioManager.RINGER_MODE_VIBRATE else AudioManager.RINGER_MODE_NORMAL
        } catch (_: Exception) {}
    }

    data class Tile(val key: String, val label: String, val state: String, val on: Boolean, val icon: Int)

    fun tiles(c: Context, count: Int): List<Tile> {
        val cm = c.getSystemService(ConnectivityManager::class.java)
        val caps = try { cm?.getNetworkCapabilities(cm.activeNetwork) } catch (_: Exception) { null }
        val wifiOn = try { c.applicationContext.getSystemService(WifiManager::class.java)?.isWifiEnabled == true } catch (_: Exception) { false }
        val onWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val onCell = caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
        val bt = bluetooth(c)
        val btConnected = bt.devices.count { it.connected }
        val am = c.getSystemService(AudioManager::class.java)
        val ring = am?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL
        val saver = c.getSystemService(PowerManager::class.java)?.isPowerSaveMode == true
        val loc = try {
            val lm = c.getSystemService(LocationManager::class.java)
            if (Build.VERSION.SDK_INT >= 28) lm?.isLocationEnabled == true else true
        } catch (_: Exception) { false }
        val dnd = try {
            (c.getSystemService(NotificationManager::class.java)?.currentInterruptionFilter ?: 1) > NotificationManager.INTERRUPTION_FILTER_ALL
        } catch (_: Exception) { false }
        val all = listOf(
            Tile("wifi", "Wi-Fi", if (onWifi) "Connected" else if (wifiOn) "On" else "Off", wifiOn, if (wifiOn) G.WIFI else G.WIFI_OFF),
            Tile("bt", "Bluetooth", if (!bt.enabled) "Off" else if (btConnected > 0) "$btConnected connected" else "On", bt.enabled, G.BT),
            Tile("torch", "Flashlight", if (torchOn) "On" else "Off", torchOn, if (torchOn) G.TORCH else G.TORCH_OFF),
            Tile(
                "sound", "Sound",
                when (ring) { AudioManager.RINGER_MODE_NORMAL -> "Ring"; AudioManager.RINGER_MODE_VIBRATE -> "Vibrate"; else -> "Silent" },
                ring == AudioManager.RINGER_MODE_NORMAL,
                when (ring) { AudioManager.RINGER_MODE_NORMAL -> G.SPEAKER; AudioManager.RINGER_MODE_VIBRATE -> G.VIBRATE; else -> G.MUTE },
            ),
            Tile("data", "Mobile data", if (onCell) "In use" else "Tap to open", onCell, G.CELL),
            Tile("saver", "Battery saver", if (saver) "On" else "Off", saver, G.SAVER),
            Tile("location", "Location", if (loc) "On" else "Off", loc, if (loc) G.LOCATION else G.LOCATION_OFF),
            Tile("dnd", "Focus", if (dnd) "Do not disturb" else "Off", dnd, G.MOON),
            Tile("hotspot", "Hotspot", "Tap to open", false, G.HOTSPOT),
        )
        return all.take(count)
    }

    // ───────────────────────── steps (real sensor) ─────────────────────────

    fun hasActivityPermission(c: Context) =
        Build.VERSION.SDK_INT < 29 || c.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    /** Steps today from the hardware step counter (counts since boot; we keep a midnight baseline). */
    fun steps(c: Context, done: (Int) -> Unit) {
        if (!hasActivityPermission(c)) return done(-1)
        val sm = c.getSystemService(SensorManager::class.java)
        val sensor = sm?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return done(-1)
        var finished = false
        lateinit var listener: SensorEventListener
        val timeout = Runnable {
            if (!finished) {
                finished = true
                sm.unregisterListener(listener)
                done(storedSteps(c))
            }
        }
        listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                if (finished) return
                finished = true
                main.removeCallbacks(timeout)
                sm.unregisterListener(this)
                done(recordSteps(c, e.values[0].toLong()))
            }

            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL, main)
        main.postDelayed(timeout, 2500)
    }

    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun recordSteps(c: Context, total: Long): Int {
        val p = HomeWidgetPlugin.getData(c)
        val day = p.getString("so_steps_day", null)
        var base = p.getLong("so_steps_base", total)
        val last = p.getLong("so_steps_last", total)
        if (day != today()) {
            base = if (last in 1..total) last else total
        }
        if (total < base) base = 0 // rebooted
        p.edit().putString("so_steps_day", today()).putLong("so_steps_base", base).putLong("so_steps_last", total).apply()
        return (total - base).toInt()
    }

    private fun storedSteps(c: Context): Int {
        val p = HomeWidgetPlugin.getData(c)
        if (p.getString("so_steps_day", null) != today()) return 0
        return (p.getLong("so_steps_last", 0) - p.getLong("so_steps_base", 0)).toInt().coerceAtLeast(0)
    }

    // ───────────────────────── Flutter channel ─────────────────────────

    fun attach(c: Context, messenger: BinaryMessenger): () -> Unit {
        val ch = MethodChannel(messenger, "so_widget/device")
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "stats" -> {
                        val s = storage(c)
                        val ph = phone(c)
                        steps(c) { st ->
                            result.success(mapOf(
                                "storageTotal" to s.total, "storageFree" to s.free,
                                "ramTotal" to s.ramTotal, "ramFree" to s.ramFree,
                                "battery" to ph.level, "charging" to ph.charging, "temp" to ph.tempC.toDouble(),
                                "uptime" to SystemClock.elapsedRealtime(), "cores" to Runtime.getRuntime().availableProcessors(),
                                "android" to Build.VERSION.RELEASE, "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                                "steps" to st,
                            ))
                        }
                    }
                    "bluetooth" -> {
                        val b = bluetooth(c)
                        result.success(mapOf(
                            "permitted" to b.permitted, "available" to b.available, "enabled" to b.enabled,
                            "devices" to b.devices.map { mapOf("name" to it.name, "address" to it.address, "connected" to it.connected, "battery" to it.battery, "icon" to it.icon) },
                        ))
                    }
                    "btToggle" -> {
                        val i = Intent(c, SoDeviceActivity::class.java)
                            .putExtra("action", "bt").putExtra("address", call.argument<String>("address"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        c.startActivity(i)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("device", e.message, null)
            }
        }
        return { ch.setMethodCallHandler(null) }
    }

    // ───────────────────────── widgets ─────────────────────────

    private fun instances(c: Context): List<Triple<Int, String, String>> {
        val prefs = HomeWidgetPlugin.getData(c)
        val mgr = AppWidgetManager.getInstance(c)
        return SoHome.providers.flatMap { (slot, cls) ->
            mgr.getAppWidgetIds(ComponentName(c, cls)).toList().mapNotNull { wid: Int ->
                val id = prefs.getString(SoHome.instKey(wid), null)
                if (id != null && isDevice(id)) Triple<Int, String, String>(wid, slot, id) else null
            }
        }
    }

    fun updateAll(context: Context) {
        val c = context.applicationContext
        val mgr = AppWidgetManager.getInstance(c)
        for ((wid, slot, id) in instances(c)) {
            try { render(c, mgr, wid, slot, id) } catch (_: Exception) {}
        }
    }

    /** Refresh shortly after an action, when the system state has settled. */
    fun updateSoon(context: Context) {
        val c = context.applicationContext
        main.postDelayed({ updateAll(c) }, 400)
        main.postDelayed({ updateAll(c) }, 2500)
        main.postDelayed({ updateAll(c) }, 6000)
    }

    private fun layoutFor(wDp: Int, hDp: Int) = when {
        hDp < 118 -> "strip"
        wDp < 230 -> "small"
        hDp <= 230 -> "medium"
        else -> "large"
    }

    /** What a tap on a zone does. */
    sealed class Act {
        data class Bt(val address: String) : Act()
        data class Broadcast(val action: String) : Act()
        data class Open(val intent: Intent) : Act()
    }

    data class Zone(val rect: RectF, val act: Act)

    fun preview(c: Context, id: String, wDp: Int, hDp: Int, styleJson: String?): ByteArray {
        val d = c.resources.displayMetrics.density.coerceAtMost(2.6f)
        val bmp = Bitmap.createBitmap((wDp * d).toInt(), (hDp * d).toInt(), Bitmap.Config.ARGB_8888)
        Painter(c, Canvas(bmp), d, SoNowPlaying.parseStyle(styleJson), bmp.width.toFloat(), bmp.height.toFloat(), min(wDp, hDp))
            .draw(id, layoutFor(wDp, hDp))
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }

    private val zoneIds = listOf(
        R.id.g_c0 to R.id.g_b0, R.id.g_c1 to R.id.g_b1, R.id.g_c2 to R.id.g_b2,
        R.id.g_c3 to R.id.g_b3, R.id.g_c4 to R.id.g_b4, R.id.g_c5 to R.id.g_b5,
        R.id.g_c6 to R.id.g_b6, R.id.g_c7 to R.id.g_b7, R.id.g_c8 to R.id.g_b8,
    )

    fun render(c: Context, mgr: AppWidgetManager, wid: Int, slot: String, id: String) {
        ensureCallbacks(c)
        val st = SoNowPlaying.parseStyle(HomeWidgetPlugin.getData(c).getString("so_style_$id", null))
        val d = c.resources.displayMetrics.density
        val opts = mgr.getAppWidgetOptions(wid)
        val fb = when (slot) { "small" -> 170 to 170; "medium" -> 360 to 170; else -> 360 to 380 }
        var wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        var hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        if (wDp < 60 || hDp < 60) { wDp = fb.first; hDp = fb.second }
        wDp = wDp.coerceIn(80, 600)
        hDp = hDp.coerceIn(80, 700)
        val w = (wDp * d).toInt()
        val h = (hDp * d).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val painter = Painter(c, Canvas(bmp), d, st, w.toFloat(), h.toFloat(), min(wDp, hDp))
        val zones = painter.draw(id, layoutFor(wDp, hDp))

        val views = RemoteViews(c.packageName, R.layout.so_grid)
        views.setImageViewBitmap(R.id.g_image, bmp)
        zoneIds.forEachIndexed { i, (container, button) ->
            val z = zones.getOrNull(i)
            if (z == null) {
                views.setViewVisibility(container, View.GONE)
            } else {
                views.setViewVisibility(container, View.VISIBLE)
                views.setViewPadding(container, z.rect.left.toInt(), z.rect.top.toInt(), (w - z.rect.right).toInt(), (h - z.rect.bottom).toInt())
                views.setOnClickPendingIntent(button, pending(c, wid, i, z.act))
            }
        }
        views.setOnClickPendingIntent(R.id.g_root, rootIntent(c, wid, id, painter.rootAct))
        mgr.updateAppWidget(wid, views)
    }

    private fun flags() = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun pending(c: Context, wid: Int, i: Int, a: Act): PendingIntent {
        val code = wid * 31 + i
        return when (a) {
            is Act.Bt -> PendingIntent.getActivity(
                c, code,
                Intent(c, SoDeviceActivity::class.java).putExtra("action", "bt").putExtra("address", a.address)
                    .setData(Uri.parse("sowidget://bt/${a.address}/$wid"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION),
                flags(),
            )
            is Act.Broadcast -> PendingIntent.getBroadcast(
                c, code,
                Intent(c, SoDeviceReceiver::class.java).setAction("uz.qaxxorov.so_widget.${a.action}").setData(Uri.parse("sowidget://act/${a.action}/$wid")),
                flags(),
            )
            is Act.Open -> PendingIntent.getActivity(c, code, a.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), flags())
        }
    }

    private fun rootIntent(c: Context, wid: Int, id: String, a: Act?): PendingIntent =
        if (a != null) pending(c, wid, 99, a)
        else HomeWidgetLaunchIntent.getActivity(c, MainActivity::class.java, Uri.parse("sowidget://open?id=$id&wid=$wid"))

    fun settingsIntent(key: String): Intent = when (key) {
        "wifi" -> if (Build.VERSION.SDK_INT >= 29) Intent(Settings.Panel.ACTION_WIFI) else Intent(Settings.ACTION_WIFI_SETTINGS)
        "bt" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        "data" -> if (Build.VERSION.SDK_INT >= 29) Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY) else Intent(Settings.ACTION_DATA_ROAMING_SETTINGS)
        "saver" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        "dnd" -> Intent("android.settings.ZEN_MODE_SETTINGS")
        "hotspot" -> Intent("android.settings.TETHER_SETTINGS")
        "storage" -> Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
        else -> Intent(Settings.ACTION_SETTINGS)
    }

    // ───────────────────────── drawing ─────────────────────────

    private class Painter(
        val ctx: Context,
        val cv: Canvas,
        val d: Float,
        val st: SoNowPlaying.Style,
        val w: Float,
        val h: Float,
        minDp: Int,
    ) {
        fun u(v: Float) = v * d
        val pad = u(if (minDp < 200) 14f else 18f)
        val radius = min(st.radius / 170f * minDp * d, min(w, h) / 2f)
        val fg = st.fg
        val accent = if (st.accent == st.fg) st.fg else st.accent
        val good = if (st.accent == st.fg) Color.rgb(48, 209, 88) else st.accent
        val bold: Typeface = SoNowPlaying.typeface(ctx, st.font, SoNowPlaying.weightsFor(3, st.weight), Typeface.create("sans-serif", Typeface.BOLD))
        val medium: Typeface = SoNowPlaying.typeface(ctx, st.font, SoNowPlaying.weightsFor(2, st.weight), Typeface.create("sans-serif-medium", Typeface.NORMAL))
        val iconTf: Typeface? = icons(ctx)
        val full = RectF(0f, 0f, w, h)
        var rootAct: Act? = null

        fun alpha(color: Int, a: Float) =
            Color.argb((Color.alpha(color) * a).toInt().coerceIn(0, 255), Color.red(color), Color.green(color), Color.blue(color))

        fun lighten(color: Int, f: Float) = Color.rgb(
            (Color.red(color) + (255 - Color.red(color)) * f).toInt(),
            (Color.green(color) + (255 - Color.green(color)) * f).toInt(),
            (Color.blue(color) + (255 - Color.blue(color)) * f).toInt(),
        )

        val dim get() = alpha(fg, 0.55f)
        fun p(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }

        fun background() {
            cv.drawRoundRect(full, radius, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, w, h, alpha(lighten(st.bg, 0.06f), st.bgOpacity), alpha(st.bg, st.bgOpacity), Shader.TileMode.CLAMP)
            })
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

        fun tp(sizeDp: Float, color: Int, face: Typeface) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = u(sizeDp * st.textScale)
            this.color = color
            typeface = face
            letterSpacing = if (sizeDp > 16) -0.02f else 0f
        }

        /** align: 0 left, 1 center, 2 right. */
        fun text(t: String, x: Float, y: Float, maxW: Float, sizeDp: Float, color: Int, face: Typeface = medium, align: Int = 0) {
            val paint = tp(sizeDp, color, face)
            val s = TextUtils.ellipsize(t, paint, max(1f, maxW), TextUtils.TruncateAt.END).toString()
            val tw = paint.measureText(s)
            cv.drawText(s, when (align) { 1 -> x - tw / 2; 2 -> x - tw; else -> x }, y, paint)
        }

        fun icon(cp: Int, cx: Float, cy: Float, size: Float, color: Int) {
            val tf = iconTf ?: return run { cv.drawCircle(cx, cy, size * 0.18f, p(color)) }
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                typeface = tf
                textSize = size
                this.color = color
                textAlign = Paint.Align.CENTER
            }
            val fm = paint.fontMetrics
            cv.drawText(String(Character.toChars(cp)), cx, cy - (fm.ascent + fm.descent) / 2, paint)
        }

        fun bar(l: Float, top: Float, r: Float, hh: Float, v: Float, color: Int) {
            val rad = hh / 2
            cv.drawRoundRect(RectF(l, top, r, top + hh), rad, rad, p(alpha(fg, 0.14f)))
            val fill = l + (r - l) * v.coerceIn(0f, 1f)
            if (fill <= l + hh * 0.5f) return
            val fr = RectF(l, top, fill, top + hh)
            if (st.glow) {
                cv.drawRoundRect(fr, rad, rad, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.color = alpha(color, 0.6f * st.glowStrength)
                    maskFilter = BlurMaskFilter(u(4f) + u(6f) * st.glowStrength, BlurMaskFilter.Blur.NORMAL)
                })
            }
            cv.drawRoundRect(fr, rad, rad, p(color))
        }

        fun ring(cx: Float, cy: Float, r: Float, stroke: Float, v: Float, color: Int) {
            val rect = RectF(cx - r, cy - r, cx + r, cy + r)
            cv.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                this.color = alpha(fg, 0.14f)
            })
            if (v <= 0f) return
            cv.drawArc(rect, -90f, 360f * v.coerceIn(0f, 1f), false, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
                this.color = color
            })
        }

        fun tile(r: RectF, corner: Float, on: Boolean) {
            cv.drawRoundRect(r, corner, corner, p(if (on) accent else alpha(fg, 0.09f)))
            if (!on) {
                cv.drawRoundRect(r, corner, corner, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = u(0.8f)
                    color = alpha(fg, 0.08f)
                })
            }
        }

        fun onInk() = if (Color.luminance(accent) > 0.5f) Color.rgb(17, 17, 17) else Color.WHITE

        fun header(cp: Int, title: String, trailing: String?) {
            val y = pad + u(12f)
            icon(cp, pad + u(8f), y - u(4f), u(15f), dim)
            text(title, pad + u(20f), y, w - pad * 2 - u(80f), 13f, dim)
            if (trailing != null) text(trailing, w - pad, y, u(110f), 12f, dim, align = 2)
        }

        fun message(cp: Int, title: String, sub: String, layout: String) {
            if (layout == "strip") {
                icon(cp, h / 2, h / 2, h * 0.36f, fg)
                text(title, h, h / 2 - u(1f), w - h - pad, 14f, fg, bold)
                text(sub, h, h / 2 + u(15f), w - h - pad, 11.5f, dim)
                return
            }
            icon(cp, pad + u(14f), pad + u(16f), u(26f), fg)
            text(title, pad, h - pad - u(22f), w - pad * 2, if (layout == "small") 15f else 18f, fg, bold)
            text(sub, pad, h - pad - u(4f), w - pad * 2, 12.5f, dim)
        }

        fun gb(b: Long): String {
            val g = b / 1_000_000_000.0
            return if (g >= 100) "${g.toInt()} GB" else String.format(Locale.US, "%.1f GB", g)
        }

        fun draw(id: String, layout: String): List<Zone> {
            cv.save()
            cv.clipPath(Path().apply { addRoundRect(full, radius, radius, Path.Direction.CW) })
            background()
            val zones = when (id) {
                "d_bluetooth" -> bluetooth(layout)
                "d_controls" -> controls(layout)
                "d_batteries" -> batteries(layout)
                else -> storage(layout)
            }
            cv.restore()
            border()
            return zones
        }

        // Bluetooth: paired devices, tap one to connect / disconnect.
        fun bluetooth(layout: String): List<Zone> {
            val b = bluetooth(ctx)
            if (!b.available) { message(G.BT, "No Bluetooth", "This device has no Bluetooth", layout); return emptyList() }
            if (!b.permitted) {
                rootAct = Act.Open(Intent(ctx, MainActivity::class.java).setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION).setData(Uri.parse("sowidget://permissions")))
                message(G.BT, "Allow Bluetooth", "Tap to give So Widget access", layout); return emptyList()
            }
            if (!b.enabled) {
                rootAct = Act.Bt("power")
                message(G.BT, "Bluetooth is off", "Tap to turn it on", layout); return emptyList()
            }
            if (b.devices.isEmpty()) {
                rootAct = Act.Open(settingsIntent("bt"))
                message(G.PLUS, "No paired devices", "Tap to pair a device", layout); return emptyList()
            }
            rootAct = Act.Open(settingsIntent("bt"))
            val zones = mutableListOf<Zone>()
            val connected = b.devices.count { it.connected }
            if (layout == "strip") {
                val dv = b.devices.first()
                val r = RectF(0f, 0f, w, h)
                row(dv, RectF(pad * 0.6f, 0f, w - pad * 0.6f, h), big = true)
                zones += Zone(r, Act.Bt(dv.address))
                return zones
            }
            header(G.BT, "Bluetooth", if (connected > 0) "$connected connected" else "On")
            val top = pad + u(26f)
            val area = RectF(pad * 0.6f, top, w - pad * 0.6f, h - pad * 0.6f)
            if (layout == "medium") {
                // 2 × 2 tiles
                val gap = u(8f)
                val cw = (area.width() - gap) / 2
                val ch = (area.height() - gap) / 2
                b.devices.take(4).forEachIndexed { i, dv ->
                    val col = i % 2
                    val r = i / 2
                    val rect = RectF(area.left + col * (cw + gap), area.top + r * (ch + gap), area.left + col * (cw + gap) + cw, area.top + r * (ch + gap) + ch)
                    deviceTile(dv, rect)
                    zones += Zone(rect, Act.Bt(dv.address))
                }
                return zones
            }
            val rows = if (layout == "small") 3 else 6
            val rh = area.height() / rows
            b.devices.take(rows).forEachIndexed { i, dv ->
                val rect = RectF(area.left, area.top + i * rh, area.right, area.top + (i + 1) * rh)
                row(dv, rect, big = layout == "large")
                zones += Zone(rect, Act.Bt(dv.address))
            }
            return zones
        }

        fun status(dv: Bt) = when {
            dv.connected && dv.battery >= 0 -> "Connected · ${dv.battery}%"
            dv.connected -> "Connected"
            else -> "Tap to connect"
        }

        fun row(dv: Bt, r: RectF, big: Boolean) {
            val s = min(r.height() * 0.72f, u(if (big) 40f else 32f))
            val cx = r.left + pad * 0.4f + s / 2
            val cy = r.centerY()
            cv.drawCircle(cx, cy, s / 2, p(if (dv.connected) accent else alpha(fg, 0.10f)))
            icon(dv.icon, cx, cy, s * 0.52f, if (dv.connected) onInk() else fg)
            val tx = cx + s / 2 + u(10f)
            val right = r.right - pad * 0.4f
            val hasBat = dv.connected && dv.battery >= 0 && r.width() > u(200f)
            val tw = right - tx - if (hasBat) u(52f) else 0f
            text(dv.name, tx, cy - u(1f), tw, if (big) 15f else 13.5f, fg, bold)
            text(status(dv), tx, cy + u(14f), tw, 11.5f, if (dv.connected) good else dim)
            if (hasBat) {
                bar(right - u(40f), cy - u(3f), right, u(6f), dv.battery / 100f, if (dv.battery <= 20) Color.rgb(255, 69, 58) else good)
            }
        }

        fun deviceTile(dv: Bt, r: RectF) {
            tile(r, min(radius * 0.55f, u(18f)), dv.connected)
            val ink = if (dv.connected) onInk() else fg
            icon(dv.icon, r.left + u(18f), r.top + u(20f), u(20f), ink)
            text(dv.name, r.left + u(10f), r.bottom - u(22f), r.width() - u(20f), 13f, ink, bold)
            text(status(dv), r.left + u(10f), r.bottom - u(8f), r.width() - u(20f), 10.5f, alpha(ink, 0.7f))
        }

        // Controls: Wi-Fi, Bluetooth, flashlight, sound, data, saver, location, focus, hotspot.
        fun controls(layout: String): List<Zone> {
            val (cols, rows) = when (layout) {
                "strip" -> 4 to 1
                "small" -> 2 to 2
                "medium" -> 3 to 2
                else -> 3 to 3
            }
            val ts = tiles(ctx, cols * rows)
            val zones = mutableListOf<Zone>()
            val gap = u(if (layout == "strip") 10f else 8f)
            val area = RectF(pad * 0.7f, pad * 0.7f, w - pad * 0.7f, h - pad * 0.7f)
            val cw = (area.width() - gap * (cols - 1)) / cols
            val ch = (area.height() - gap * (rows - 1)) / rows
            ts.forEachIndexed { i, t ->
                val col = i % cols
                val r = i / cols
                val rect = RectF(area.left + col * (cw + gap), area.top + r * (ch + gap), area.left + col * (cw + gap) + cw, area.top + r * (ch + gap) + ch)
                if (layout == "strip") {
                    val s = min(cw, ch)
                    val cx = rect.centerX()
                    val cy = rect.centerY()
                    cv.drawCircle(cx, cy, s / 2, p(if (t.on) accent else alpha(fg, 0.10f)))
                    icon(t.icon, cx, cy, s * 0.46f, if (t.on) onInk() else fg)
                } else {
                    tile(rect, min(radius * 0.55f, u(20f)), t.on)
                    val ink = if (t.on) onInk() else fg
                    val roomy = rect.height() > u(64f)
                    if (roomy) {
                        icon(t.icon, rect.left + u(20f), rect.top + u(21f), u(20f), ink)
                        text(t.label, rect.left + u(11f), rect.bottom - u(22f), rect.width() - u(18f), 12.5f, ink, bold)
                        text(t.state, rect.left + u(11f), rect.bottom - u(8f), rect.width() - u(18f), 10.5f, alpha(ink, 0.7f))
                    } else {
                        icon(t.icon, rect.centerX(), rect.centerY() - u(6f), u(20f), ink)
                        text(t.label, rect.centerX(), rect.bottom - u(7f), rect.width() - u(8f), 10f, alpha(ink, 0.8f), align = 1)
                    }
                }
                val act = when (t.key) {
                    "torch" -> Act.Broadcast("torch")
                    "sound" -> Act.Broadcast("sound")
                    "bt" -> if (t.on) Act.Open(settingsIntent("bt")) else Act.Bt("power")
                    else -> Act.Open(settingsIntent(t.key))
                }
                zones += Zone(rect, act)
            }
            return zones
        }

        // Batteries: phone plus connected Bluetooth devices that report a level.
        fun batteries(layout: String): List<Zone> {
            data class B(val icon: Int, val name: String, val level: Int, val charging: Boolean)
            val ph = phone(ctx)
            val items = mutableListOf(B(G.PHONE, Build.MODEL ?: "Phone", ph.level, ph.charging))
            bluetooth(ctx).devices.filter { it.connected && it.battery >= 0 }.forEach { items += B(it.icon, it.name, it.battery, false) }
            fun color(l: Int) = if (l in 0..20) Color.rgb(255, 69, 58) else good
            when (layout) {
                "large" -> {
                    header(G.BATTERY, "Batteries", null)
                    val top = pad + u(30f)
                    val rh = min(u(58f), (h - top - pad) / max(1, items.size.coerceAtMost(6)))
                    items.take(6).forEachIndexed { i, b ->
                        val cy = top + rh * i + rh / 2
                        val s = min(rh * 0.7f, u(38f))
                        cv.drawCircle(pad + s / 2, cy, s / 2, p(alpha(fg, 0.10f)))
                        icon(b.icon, pad + s / 2, cy, s * 0.5f, fg)
                        val tx = pad + s + u(12f)
                        text(b.name, tx, cy - u(4f), w - tx - pad - u(56f), 14f, fg, bold)
                        bar(tx, cy + u(5f), w - pad - u(56f), u(6f), b.level / 100f, color(b.level))
                        text("${b.level}%" + if (b.charging) " ⚡" else "", w - pad, cy + u(6f), u(56f), 15f, fg, bold, align = 2)
                    }
                }
                else -> {
                    val n = when (layout) { "strip" -> 4; "small" -> 4; else -> 4 }
                    val list = items.take(n)
                    val cols = if (layout == "small") 2 else list.size.coerceAtLeast(1)
                    val rows = if (layout == "small") (list.size + 1) / 2 else 1
                    val area = RectF(pad * 0.6f, pad * 0.6f, w - pad * 0.6f, h - pad * 0.6f)
                    val cw = area.width() / cols
                    val chh = area.height() / max(1, rows)
                    list.forEachIndexed { i, b ->
                        val cx = area.left + cw * (i % cols) + cw / 2
                        val cyTop = area.top + chh * (i / cols)
                        val labelH = if (layout == "strip") 0f else u(18f)
                        val r = min(cw, chh - labelH) * 0.38f
                        val cy = cyTop + (chh - labelH) / 2
                        ring(cx, cy, r, r * 0.2f, b.level / 100f, color(b.level))
                        if (layout == "strip") {
                            text("${b.level}%", cx, cy + u(4f), r * 1.6f, 11f, fg, bold, align = 1)
                        } else {
                            icon(if (b.charging) G.BOLT else b.icon, cx, cy, r * 0.9f, fg)
                            text("${b.level}%", cx, cyTop + chh - u(4f), cw - u(6f), 13f, fg, bold, align = 1)
                        }
                    }
                }
            }
            rootAct = Act.Open(Intent(Intent.ACTION_POWER_USAGE_SUMMARY))
            return emptyList()
        }

        // Storage: real disk and memory usage.
        fun storage(layout: String): List<Zone> {
            val s = storage(ctx)
            val used = if (s.total > 0) 1f - s.free.toFloat() / s.total else 0f
            val ram = if (s.ramTotal > 0) 1f - s.ramFree.toFloat() / s.ramTotal else 0f
            val ph = phone(ctx)
            rootAct = Act.Open(settingsIntent("storage"))
            val warn = Color.rgb(255, 159, 10)
            fun col(v: Float) = if (v > 0.9f) Color.rgb(255, 69, 58) else if (v > 0.75f) warn else accent
            when (layout) {
                "strip" -> {
                    icon(G.STORAGE, h / 2, h / 2, h * 0.34f, fg)
                    val tx = h
                    text("${gb(s.free)} free", tx, h / 2 - u(3f), w - tx - pad, 15f, fg, bold)
                    bar(tx, h / 2 + u(6f), w - pad, u(5f), used, col(used))
                }
                "small" -> {
                    header(G.STORAGE, "Storage", null)
                    text(gb(s.free), pad, pad + u(64f), w - pad * 2, 30f, fg, bold)
                    text("free of ${gb(s.total)}", pad, pad + u(82f), w - pad * 2, 12f, dim)
                    bar(pad, h - pad - u(34f), w - pad, u(8f), used, col(used))
                    text("RAM ${(ram * 100).toInt()}% used", pad, h - pad - u(6f), w - pad * 2, 11.5f, dim)
                }
                "medium" -> {
                    header(G.STORAGE, "Storage & memory", "${ph.tempC.toInt()}°C")
                    val colW = (w - pad * 3) / 2
                    block("Storage", gb(s.free) + " free", "of ${gb(s.total)}", used, col(used), pad, colW)
                    block("Memory", gb(s.ramFree) + " free", "of ${gb(s.ramTotal)}", ram, col(ram), pad * 2 + colW, colW)
                }
                else -> {
                    header(G.STORAGE, "Storage & memory", Build.MODEL)
                    text(gb(s.free), pad, pad + u(78f), w - pad * 2, 44f, fg, bold)
                    text("free of ${gb(s.total)} · ${(used * 100).toInt()}% used", pad, pad + u(100f), w - pad * 2, 13f, dim)
                    bar(pad, pad + u(116f), w - pad, u(10f), used, col(used))
                    text("Memory", pad, pad + u(160f), w, 13f, dim)
                    text("${gb(s.ramTotal - s.ramFree)} of ${gb(s.ramTotal)}", w - pad, pad + u(160f), w, 13f, fg, bold, align = 2)
                    bar(pad, pad + u(170f), w - pad, u(8f), ram, col(ram))
                    val up = SystemClock.elapsedRealtime() / 60000
                    val stats = listOf(
                        "Battery" to "${ph.level}%", "Temp" to "${ph.tempC.toInt()}°C",
                        "Uptime" to "${up / 1440}d ${(up % 1440) / 60}h", "Android" to (Build.VERSION.RELEASE ?: ""),
                    )
                    val sw = (w - pad * 2) / 4
                    stats.forEachIndexed { i, (k, v) ->
                        text(k, pad + sw * i, h - pad - u(22f), sw - u(4f), 11.5f, dim)
                        text(v, pad + sw * i, h - pad - u(4f), sw - u(4f), 16f, fg, bold)
                    }
                }
            }
            return emptyList()
        }

        fun block(title: String, big: String, sub: String, v: Float, color: Int, x: Float, cw: Float) {
            text(title, x, pad + u(48f), cw, 12f, dim)
            text(big, x, pad + u(72f), cw, 20f, fg, bold)
            text(sub, x, pad + u(88f), cw, 11.5f, dim)
            bar(x, h - pad - u(12f), x + cw, u(7f), v, color)
        }
    }
}

/** Torch / sound taps, and system events that should refresh device widgets. */
class SoDeviceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "uz.qaxxorov.so_widget.torch" -> SoDevices.toggleTorch(context)
            "uz.qaxxorov.so_widget.sound" -> SoDevices.cycleSound(context)
        }
        SoDevices.updateAll(context)
        SoDevices.updateSoon(context)
    }
}

/**
 * Invisible activity started by a widget tap. Connects / disconnects a Bluetooth device in one tap
 * (or turns Bluetooth on). Falls back to Bluetooth settings where the phone doesn't allow it.
 */
class SoDeviceActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private val proxies = mutableMapOf<Int, BluetoothProfile>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val address = intent?.getStringExtra("address")
        if (!SoDevices.hasBtPermission(this)) {
            startActivity(Intent(this, MainActivity::class.java).setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION).setData(Uri.parse("sowidget://permissions")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return finish()
        }
        val adapter = SoDevices.adapter(this) ?: return finish()
        val enabled = try { adapter.isEnabled } catch (_: SecurityException) { false }
        if (address == null || address == "power" || !enabled) {
            try {
                startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
            } catch (_: Exception) {
                openSettings()
            }
            SoDevices.updateSoon(this)
            return finish()
        }
        val device = try { adapter.getRemoteDevice(address) } catch (_: Exception) { null } ?: return finish()
        val connect = !SoDevices.isConnected(device)
        Toast.makeText(this, if (connect) "Connecting…" else "Disconnecting…", Toast.LENGTH_SHORT).show()
        val profiles = listOf(BluetoothProfile.A2DP, BluetoothProfile.HEADSET)
        var pending = profiles.size
        val listener = object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                proxies[profile] = proxy
                if (--pending == 0) act(device, connect)
            }

            override fun onServiceDisconnected(profile: Int) {}
        }
        profiles.forEach { pr ->
            try {
                if (!adapter.getProfileProxy(this, listener, pr)) pending--
            } catch (_: Exception) { pending-- }
        }
        // Don't wait forever for a profile that never binds.
        main.postDelayed({ if (!isFinishing) act(device, connect) }, 2500)
    }

    private var done = false

    private fun act(device: BluetoothDevice, connect: Boolean) {
        if (done) return
        done = true
        var ok = false
        for ((_, proxy) in proxies) {
            try {
                proxy.javaClass.getMethod(if (connect) "connect" else "disconnect", BluetoothDevice::class.java).invoke(proxy, device)
                ok = true
            } catch (_: Throwable) {}
        }
        val adapter = SoDevices.adapter(this)
        proxies.forEach { (pr, proxy) -> try { adapter?.closeProfileProxy(pr, proxy) } catch (_: Exception) {} }
        if (!ok) {
            Toast.makeText(this, "Your phone asks to do this in Bluetooth settings", Toast.LENGTH_SHORT).show()
            openSettings()
        }
        SoDevices.updateSoon(this)
        finish()
    }

    private fun openSettings() {
        try {
            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {}
    }
}
