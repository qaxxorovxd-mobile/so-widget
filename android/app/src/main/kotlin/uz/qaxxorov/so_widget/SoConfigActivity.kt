package uz.qaxxorov.so_widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import android.widget.SearchView
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/** Native picker shown when a widget is added from the launcher, reconfigured, or tapped while empty. */
class SoConfigActivity : Activity() {
    private var wid = AppWidgetManager.INVALID_APPWIDGET_ID
    private var current: String? = null

    private data class Item(val id: String, val no: Int, val name: String, val cat: String)

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wid = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid))
        if (wid == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK

        current = HomeWidgetPlugin.getData(this).getString("so_inst_$wid", null)
        val items = loadCatalog().sortedBy { if (it.id == current) 0 else 1 }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            fitsSystemWindows = true
            setPadding(dp(16), dp(20), dp(16), 0)
        }
        root.addView(TextView(this).apply {
            text = getString(R.string.so_pick_title)
            setTextColor(Color.WHITE)
            textSize = 24f
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
        })
        root.addView(TextView(this).apply {
            text = if (items.isEmpty()) getString(R.string.so_pick_first_run) else getString(R.string.so_pick_subtitle)
            setTextColor(Color.parseColor("#99EBEBF5"))
            textSize = 13f
            setPadding(0, dp(4), 0, dp(16))
        })

        if (items.isEmpty()) {
            root.addView(TextView(this).apply {
                text = getString(R.string.so_pick_open)
                setTextColor(Color.BLACK)
                textSize = 16f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                background = GradientDrawable().apply { setColor(Color.WHITE); cornerRadius = dp(16).toFloat() }
                setPadding(0, dp(14), 0, dp(14))
                setOnClickListener { openApp("sowidget://open") }
            })
        } else {
            val choices = Adapter(items)
            root.addView(SearchView(this).apply {
                setIconifiedByDefault(false)
                queryHint = "Search widgets"
                setOnQueryTextListener(object : SearchView.OnQueryTextListener {
                    override fun onQueryTextSubmit(query: String?) = false
                    override fun onQueryTextChange(query: String?): Boolean {
                        val q = query.orEmpty().trim()
                        choices.items = items.filter {
                            "${it.name} ${it.cat} ${it.no.toString().padStart(2, '0')}".contains(q, ignoreCase = true)
                        }
                        choices.notifyDataSetChanged()
                        return true
                    }
                })
                clearFocus()
            })
            val list = ListView(this).apply {
                divider = null
                selector = GradientDrawable().apply { setColor(Color.parseColor("#22FFFFFF")) }
                adapter = choices
                setOnItemClickListener { _, _, pos, _ -> choose(choices.getItem(pos).id) }
            }
            root.addView(list, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        }
        setContentView(root)
    }

    private fun loadCatalog(): List<Item> = try {
        val raw = HomeWidgetPlugin.getData(this).getString("so_catalog", null) ?: "[]"
        val arr = JSONArray(raw)
        (0 until arr.length()).map {
            val o = arr.getJSONObject(it)
            Item(o.getString("id"), o.getInt("no"), o.getString("name"), o.optString("cat"))
        }
    } catch (e: Exception) {
        emptyList()
    }

    private fun choose(id: String) {
        SoHome.assign(this, wid, id)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, wid))
        // Let the app render the snapshot for this widget, then it steps back to the home screen.
        openApp("sowidget://render?wid=$wid&id=$id")
    }

    private fun openApp(uri: String) {
        try {
            HomeWidgetLaunchIntent.getActivity(this, MainActivity::class.java, Uri.parse(uri)).send()
        } catch (_: Exception) {
        }
        finish()
    }

    private inner class Adapter(var items: List<Item>) : BaseAdapter() {
        override fun getCount() = items.size
        override fun getItem(position: Int) = items[position]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val it = items[position]
            val row = (convertView as? LinearLayout) ?: LinearLayout(this@SoConfigActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(4), dp(13), dp(4), dp(13))
                addView(TextView(context).apply {
                    setTextColor(Color.parseColor("#4DEBEBF5"))
                    textSize = 13f
                    typeface = Typeface.MONOSPACE
                    minWidth = dp(34)
                })
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(TextView(context).apply { setTextColor(Color.WHITE); textSize = 14f })
                    addView(TextView(context).apply { setTextColor(Color.parseColor("#99EBEBF5")); textSize = 12f })
                }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            }
            (row.getChildAt(0) as TextView).text = it.no.toString().padStart(2, '0')
            val col = row.getChildAt(1) as LinearLayout
            (col.getChildAt(0) as TextView).text = it.name
            (col.getChildAt(1) as TextView).text = if (it.id == current) "${it.cat} · Selected ✓" else it.cat
            return row
        }
    }
}
