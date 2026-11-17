package uz.qaxxorov.so_widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Status and request screens for everything So Widget needs to work fully. */
object SoPermissions {
    private val brand get() = Build.MANUFACTURER.lowercase()

    /** Brands that kill background work unless the app is allowed to auto-start. */
    private val autostartIntents = listOf(
        ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
        ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
        ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity"),
    )

    @Suppress("UNUSED_PARAMETER")
    private fun hasAutostart(a: Activity) = listOf(
        "xiaomi", "redmi", "poco", "oppo", "realme", "oneplus", "vivo", "iqoo", "huawei", "honor", "letv", "asus",
    ).any { brand.contains(it) }

    fun status(a: Activity): Map<String, Any> {
        val pm = a.getSystemService(PowerManager::class.java)
        val battery = Build.VERSION.SDK_INT < 23 || pm?.isIgnoringBatteryOptimizations(a.packageName) == true
        val pin = Build.VERSION.SDK_INT >= 26 &&
            a.getSystemService(AppWidgetManager::class.java)?.isRequestPinAppWidgetSupported == true
        return mapOf(
            "media" to SoMedia.allowed(a),
            "battery" to battery,
            "autostart" to hasAutostart(a),
            "brand" to Build.MANUFACTURER,
            "pin" to pin,
        )
    }

    private fun start(a: Activity, i: Intent): Boolean = try {
        a.startActivity(i)
        true
    } catch (_: Exception) {
        false
    }

    private fun appDetails(a: Activity) =
        start(a, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${a.packageName}")))

    fun attach(a: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "so_widget/permissions").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status(a))
                "media" -> result.success(
                    start(a, Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) || appDetails(a),
                )
                "battery" -> {
                    val ok = Build.VERSION.SDK_INT >= 23 && (
                        start(a, Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${a.packageName}"))) ||
                            start(a, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        )
                    result.success(ok || appDetails(a))
                }
                "autostart" -> {
                    val ok = autostartIntents.any { start(a, Intent().setComponent(it)) }
                    result.success(ok || appDetails(a))
                }
                "app" -> result.success(appDetails(a))
                else -> result.notImplemented()
            }
        }
    }
}
