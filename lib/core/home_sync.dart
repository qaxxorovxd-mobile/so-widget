import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import 'media.dart';
import 'registry.dart';
import 'state.dart';
import 'style.dart';

/// One widget placed on the home screen. Each instance shows its own So Widget.
class HomeInstance {
  const HomeInstance(this.wid, this.size, this.id, [this.dims]);
  final int wid;

  /// Which provider it was added as (Small / Medium / Large). Its real size is [dims].
  final WSize size;
  final String? id;

  /// Real size on the home screen in dp (changes when the user resizes it).
  final Size? dims;

  RenderPlan get plan => dims == null ? RenderPlan(size, size.logical) : planFor(dims!.width, dims!.height);

  String get sizeLabel {
    final d = dims;
    if (d == null) return size.label;
    int cells(double v) => ((v + 16) / 90).round().clamp(1, 6);
    return '${cells(d.width)}×${cells(d.height)}';
  }

  WDef? get def => id == null ? null : widgetById[id];
}

/// Renders So Widgets to images and pushes them to each Android home-screen instance.
///
/// Shared keys with the native side (SoWidgets.kt):
///   `so_inst_{appWidgetId}` -> So Widget id
///   `so_img_{id}_{size}`    -> rendered image path
///   so_catalog            -> JSON list used by the native picker
class HomeSync {
  static const _native = MethodChannel('so_widget/native');
  static const _home = MethodChannel('so_widget/home');
  static const providers = {
    WSize.small: 'uz.qaxxorov.so_widget.SoSmallWidget',
    WSize.medium: 'uz.qaxxorov.so_widget.SoMediumWidget',
    WSize.large: 'uz.qaxxorov.so_widget.SoLargeWidget',
  };

  /// Current home-screen instances (for Studio).
  static final placed = ValueNotifier<List<HomeInstance>>(const []);

  static Timer? _debounce;
  static bool _busy = false;
  static bool _again = false;

  static bool get supported => Platform.isAndroid;

  static void init() {
    if (!supported) return;
    writeCatalog();
    // The launcher resized a widget: redraw it at its new size right away.
    _home.setMethodCallHandler((call) async {
      if (call.method == 'resized') schedule(const Duration(milliseconds: 150));
    });
    app.clock.minute.addListener(schedule);
    app.store.addListener(schedule);
    app.settings.addListener(schedule);
    app.hub.addListener(schedule);
    app.pix.addListener(schedule);
    var lastTrack = '';
    media.addListener(() {
      final m = media.value;
      final key = '${m.title}|${m.artist}|${m.playing}|${media.artwork?.hashCode}';
      if (key != lastTrack) {
        lastTrack = key;
        schedule(const Duration(milliseconds: 800));
      }
    });
  }

  static void schedule([Duration delay = const Duration(seconds: 3)]) {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncAll);
  }

  static Future<void> writeCatalog() async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'so_catalog',
        jsonEncode([
          for (final w in allWidgets) {'id': w.id, 'no': w.no, 'name': w.name, 'cat': w.cat.label},
        ]),
      );
    } catch (_) {}
  }

  static Future<List<HomeInstance>> instances() async {
    if (!supported) return const [];
    final out = <HomeInstance>[];
    await _loadDensity();
    try {
      final sizes = <int, Size>{};
      try {
        final raw = await _home.invokeMapMethod<dynamic, dynamic>('sizes') ?? {};
        raw.forEach((k, v) {
          final l = (v as List).cast<num>();
          sizes[int.parse('$k')] = Size(l[0].toDouble(), l[1].toDouble());
        });
      } catch (_) {}
      for (final w in await HomeWidget.getInstalledWidgets()) {
        // The plugin returns the short class name (".SoSmallWidget"), so compare simple names.
        final simple = (w.androidClassName ?? '').split('.').last;
        final size = providers.entries.where((e) => e.value.split('.').last == simple).firstOrNull?.key;
        final wid = w.androidWidgetId;
        if (size == null || wid == null) continue;
        final id = await HomeWidget.getWidgetData<String>('so_inst_$wid');
        out.add(HomeInstance(wid, size, widgetById.containsKey(id) ? id : null, sizes[wid]));
      }
    } catch (e) {
      debugPrint('HomeSync.instances: $e');
    }
    out.sort((a, b) => a.wid.compareTo(b.wid));
    placed.value = out;
    return out;
  }

  /// Re-renders every widget that is on the home screen and refreshes all instances.
  static Future<void> syncAll() async {
    if (!supported) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      final list = await instances();
      await _writeStyles(list);
      for (final i in list) {
        if (i.id != null && !isNative(i.id!)) await _render(i);
      }
      for (final size in {for (final i in list) i.size}) {
        await HomeWidget.updateWidget(qualifiedAndroidName: providers[size]);
      }
      // Keep the 5-minute background refresh chain alive while widgets exist.
      if (list.isNotEmpty) {
        try {
          await _native.invokeMethod('scheduleRefresh');
        } catch (_) {}
      }
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        schedule(const Duration(milliseconds: 300));
      }
    }
  }

  /// Runs inside the background engine started by SoRefreshJob (about every 5 minutes).
  /// First pass triggers network fetches, second pass renders the fresh data.
  static Future<bool> backgroundRefresh() async {
    final list = await instances();
    await _writeStyles(list);
    final todo = [for (final i in list) if (i.id != null && !isNative(i.id!)) i];
    if (todo.isEmpty) return true;
    for (final i in todo) {
      await _render(i);
    }
    final until = DateTime.now().add(const Duration(seconds: 45));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    while (!app.hub.idle && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    for (final i in todo) {
      await _render(i);
    }
    for (final size in {for (final i in list) i.size}) {
      await HomeWidget.updateWidget(qualifiedAndroidName: providers[size]);
    }
    return true;
  }

  static double _knownDpr = 0;

  /// Screen density. In the background the view can report 1.0, so remember the real value.
  static double get _dpr {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final v = views.isEmpty ? 0.0 : views.first.devicePixelRatio;
    if (_knownDpr <= 0 && v > 1.2) _knownDpr = v;
    return _knownDpr > 0 ? _knownDpr : (v > 1.2 ? v : 2.75);
  }

  static Future<void> _loadDensity() async {
    if (_knownDpr > 0) return;
    try {
      final d = await _home.invokeMethod<double>('density');
      if (d != null && d > 0) _knownDpr = d;
    } catch (_) {}
  }

  /// Draws one home-screen widget at its real size and saves it under its own key.
  static Future<void> _render(HomeInstance inst) async {
    final id = inst.id;
    final def = id == null ? null : widgetById[id];
    if (def == null || id == null) return;
    final plan = inst.plan;
    final logical = plan.logical;
    final realW = inst.dims?.width ?? logical.width;
    var ratio = realW * _dpr / logical.width;
    // Keep bitmaps within the launcher's memory budget.
    final px = logical.width * logical.height * ratio * ratio;
    if (px > 1.8e6) ratio *= math.sqrt(1.8e6 / px);
    final face = MediaQuery(
      data: MediaQueryData(size: logical, devicePixelRatio: ratio),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox.fromSize(
            size: logical,
            child: buildFace(def, app.settings.styleFor(id), plan, live: false),
          ),
        ),
      ),
    );
    try {
      await HomeWidget.renderFlutterWidget(face, key: 'so_img_w${inst.wid}', logicalSize: logical, pixelRatio: ratio)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('HomeSync render $id/$plan failed: $e');
    }
  }

  /// Adds a new home-screen widget showing [id]. Existing widgets are never touched.
  /// Rendered natively in Kotlin (SoNowPlaying.kt) so it updates instantly.
  static const nativeNowPlaying = 'nowplaying';

  /// Media widgets are drawn by Kotlin, not rendered from Flutter.
  static bool isNative(String id) => id == nativeNowPlaying || id.startsWith('m_') || id.startsWith('d_');

  /// Native widgets read their colors from here.
  static Future<void> _writeStyles(List<HomeInstance> list) async {
    for (final id in {for (final i in list) ?i.id}) {
      try {
        await HomeWidget.saveWidgetData<String>('so_style_$id', jsonEncode(app.settings.styleFor(id).toJson()));
      } catch (_) {}
    }
  }

  static Future<String> place(String id, WSize size) async {
    if (!supported) return 'Home-screen widgets are available on Android.';
    await writeCatalog();
    await _writeStyles([HomeInstance(0, size, id)]);
    bool ok = false;
    try {
      ok = await _native.invokeMethod<bool>('pin', {'slot': size.name, 'id': id}) ?? false;
    } catch (_) {}
    if (ok) {
      // The pin callback binds the new instance; refresh the list a bit later.
      Timer(const Duration(seconds: 4), syncAll);
      return 'Confirm to add it to your home screen.';
    }
    return 'Long-press your home screen → Widgets → So Widget ${size.label}, then pick ${widgetById[id]?.name ?? 'it'}.';
  }

  /// Changes which So Widget an existing home-screen instance shows.
  static Future<void> assign(HomeInstance inst, String id) async {
    await HomeWidget.saveWidgetData<String>('so_inst_${inst.wid}', id);
    await _writeStyles([HomeInstance(inst.wid, inst.size, id)]);
    if (!isNative(id)) await _render(HomeInstance(inst.wid, inst.size, id, inst.dims));
    try {
      await _native.invokeMethod('refresh', {'wid': inst.wid});
    } catch (_) {}
    await instances();
  }

  /// Handles taps on home widgets and the native picker hand-off.
  static Future<void> handleUri(Uri? uri, GlobalKey<NavigatorState> nav, Widget Function(WDef def, int? wid) detail) async {
    if (uri == null || uri.scheme != 'sowidget') return;
    if (uri.host == 'render') {
      await syncAll();
      try {
        await _native.invokeMethod('moveToBack');
      } catch (_) {}
      return;
    }
    if (uri.host == 'open') {
      final def = widgetById[uri.queryParameters['id']];
      final wid = int.tryParse(uri.queryParameters['wid'] ?? '');
      if (def != null) nav.currentState?.push(MaterialPageRoute(builder: (_) => detail(def, wid)));
    }
  }
}
