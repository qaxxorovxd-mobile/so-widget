package uz.qaxxorov.so_widget

import android.Manifest
import android.app.Activity
import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Rect
import android.media.ExifInterface
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Wallpapers: save a downloaded image to the gallery and set it as the home / lock screen wallpaper.
 * Channel "so_widget/wallpaper".
 */
object SoWallpaper {
    private const val REQ_STORAGE = 4713
    private val main = Handler(Looper.getMainLooper())

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "so_widget/wallpaper").setMethodCallHandler { call, result ->
            when (call.method) {
                "screen" -> {
                    val (w, h) = screen(activity)
                    result.success(mapOf("w" to w, "h" to h))
                }
                "save" -> {
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("arg", "path", null)
                    val name = call.argument<String>("name") ?: File(path).name
                    val mime = call.argument<String>("mime") ?: "image/jpeg"
                    val credit = call.argument<String>("credit") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    if (Build.VERSION.SDK_INT < 29 &&
                        activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                    ) {
                        activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQ_STORAGE)
                        return@setMethodCallHandler result.error("permission", "Storage permission needed", null)
                    }
                    Thread {
                        val r = try {
                            val src = withCredit(activity.applicationContext, File(path), mime, credit, artist)
                            try { save(activity.applicationContext, src, name, mime, credit) }
                            finally { if (src.path != path) src.delete() }
                        } catch (e: Exception) { e }
                        main.post {
                            if (r is Exception) result.error("save", r.message, null) else result.success(r)
                        }
                    }.start()
                }
                "set" -> {
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("arg", "path", null)
                    val target = call.argument<String>("target") ?: "both"
                    val ax = (call.argument<Double>("ax") ?: 0.5).toFloat()
                    val ay = (call.argument<Double>("ay") ?: 0.5).toFloat()
                    val (sw, sh) = screen(activity)
                    Thread {
                        val r = try { set(activity.applicationContext, File(path), target, ax, ay, sw, sh); null } catch (e: Throwable) { e }
                        main.post {
                            if (r != null) result.error("set", r.message ?: r.toString(), null) else result.success(true)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Real (full) screen size in pixels, portrait. */
    fun screen(c: Context): Pair<Int, Int> {
        val wm = c.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val (w, h) = if (Build.VERSION.SDK_INT >= 30) {
            val b = wm.maximumWindowMetrics.bounds
            b.width() to b.height()
        } else {
            val m = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(m)
            m.widthPixels to m.heightPixels
        }
        return min(w, h) to max(w, h)
    }

    /** Copy of a JPEG with the credit written into its EXIF (Artist, Copyright, Description). */
    private fun withCredit(c: Context, src: File, mime: String, credit: String, artist: String): File {
        if (credit.isEmpty() || !mime.contains("jpeg")) return src
        return try {
            val tmp = File(c.cacheDir, "credit_${src.name}")
            src.copyTo(tmp, overwrite = true)
            val exif = ExifInterface(tmp.absolutePath)
            if (artist.isNotEmpty()) exif.setAttribute(ExifInterface.TAG_ARTIST, "$artist (Wallhaven uploader)")
            exif.setAttribute(ExifInterface.TAG_COPYRIGHT, "All rights reserved by the original artist. Personal wallpaper use only.")
            exif.setAttribute(ExifInterface.TAG_IMAGE_DESCRIPTION, credit)
            exif.setAttribute(ExifInterface.TAG_SOFTWARE, "So Widget by qaxxorov.uz")
            exif.saveAttributes()
            tmp
        } catch (e: Exception) {
            src
        }
    }

    private fun save(c: Context, src: File, name: String, mime: String, credit: String): String {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/So Widget")
                put(MediaStore.Images.Media.DESCRIPTION, credit)
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val cr = c.contentResolver
            val uri = cr.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Gallery is not available")
            try {
                cr.openOutputStream(uri)!!.use { out -> FileInputStream(src).use { it.copyTo(out) } }
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                cr.update(uri, values, null, null)
            } catch (e: Exception) {
                cr.delete(uri, null, null)
                throw e
            }
            return uri.toString()
        }
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "So Widget")
        dir.mkdirs()
        val out = File(dir, name)
        src.copyTo(out, overwrite = true)
        MediaScannerConnection.scanFile(c, arrayOf(out.absolutePath), arrayOf(mime), null)
        return out.absolutePath
    }

    /** Crops the image to the screen aspect at alignment (ax, ay ∈ 0..1) and applies it. */
    private fun set(c: Context, src: File, target: String, ax: Float, ay: Float, sw: Int, sh: Int) {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(src.absolutePath, bounds)
        val iw = bounds.outWidth
        val ih = bounds.outHeight
        if (iw <= 0 || ih <= 0) throw IllegalStateException("Image could not be read")

        val screenRatio = sw.toFloat() / sh
        val crop = if (iw.toFloat() / ih > screenRatio) {
            val cw = (ih * screenRatio).roundToInt().coerceIn(1, iw)
            val x = ((iw - cw) * ax.coerceIn(0f, 1f)).roundToInt()
            Rect(x, 0, x + cw, ih)
        } else {
            val ch = (iw / screenRatio).roundToInt().coerceIn(1, ih)
            val y = ((ih - ch) * ay.coerceIn(0f, 1f)).roundToInt()
            Rect(0, y, iw, y + ch)
        }
        var sample = 1
        while (crop.width() / (sample * 2) >= sw) sample *= 2
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        @Suppress("DEPRECATION")
        val decoder = if (Build.VERSION.SDK_INT >= 31) BitmapRegionDecoder.newInstance(src.absolutePath)
        else BitmapRegionDecoder.newInstance(src.absolutePath, false)
        val region = try { decoder!!.decodeRegion(crop, opts) } finally { decoder?.recycle() }
            ?: throw IllegalStateException("Image could not be decoded")
        val bmp = if (region.width != sw || region.height != sh) {
            Bitmap.createScaledBitmap(region, sw, sh, true).also { if (it !== region) region.recycle() }
        } else region

        val wm = WallpaperManager.getInstance(c)
        val which = when (target) {
            "home" -> WallpaperManager.FLAG_SYSTEM
            "lock" -> WallpaperManager.FLAG_LOCK
            else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
        }
        try {
            wm.setBitmap(bmp, null, true, which)
        } finally {
            bmp.recycle()
        }
    }
}
