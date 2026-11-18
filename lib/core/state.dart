import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import 'style.dart';

late SharedPreferences _prefs;

String two(int n) => n.toString().padLeft(2, '0');
String dkey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// User preferences + styles.
class Settings extends ChangeNotifier {
  WStyle global = WStyle.graphite;
  final Map<String, WStyle> overrides = {};
  String themeName = 'Graphite';
  final Map<String, WStyle> themeStyles = {};
  bool use24h = true;
  bool metric = true;
  String city = 'Tashkent';
  String country = 'Uzbekistan';
  double lat = 41.2995;
  double lon = 69.2401;
  String githubUser = 'torvalds';


  WStyle styleFor(String id) => overrides[id] ?? global;
  bool hasOverride(String id) => overrides.containsKey(id);

  void setGlobal(WStyle s) {
    global = s;
    themeStyles[themeName] = s;
    _changed();
  }

  /// Switching or restoring a theme changes its colors and fonts only. Personal layout
  /// (text size, outline, corners, weight, glass, compact) stays as the user set it.
  void applyTheme(String name, {bool reset = false}) {
    final preset = kPresets.firstWhere((p) => p.name == name);
    final mine = global;
    themeName = name;
    if (reset) themeStyles.remove(name);
    global = keepLayout(themeStyles[name] ?? preset.style, mine);
    themeStyles[name] = global;
    overrides.clear();
    _changed();
  }

  void setMainColor(Color color) {
    final base = kPresets.firstWhere((p) => p.name == themeName).style;
    setGlobal(tintTheme(global, base, color));
  }

  void setOverride(String id, WStyle? s) {
    if (s == null) {
      overrides.remove(id);
    } else {
      overrides[id] = s;
    }
    _changed();
  }

  void clearOverrides() {
    overrides.clear();
    _changed();
  }

  void update(VoidCallback fn) {
    fn();
    _changed();
  }

  void _changed() {
    notifyListeners();
    _prefs.setString('settings', jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'global': global.toJson(),
        'themeName': themeName,
        'themeStyles': themeStyles.map((k, v) => MapEntry(k, v.toJson())),
        'overrides': overrides.map((k, v) => MapEntry(k, v.toJson())),
        'use24h': use24h,
        'metric': metric,
        'city': city,
        'country': country,
        'lat': lat,
        'lon': lon,
        'githubUser': githubUser,
      };

  void load() {
    final raw = _prefs.getString('settings');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      global = WStyle.fromJson(Map<String, dynamic>.from(j['global'] as Map));
      themeName = kPresets.any((p) => p.name == j['themeName']) ? j['themeName'] as String : 'Graphite';
      themeStyles.clear();
      (j['themeStyles'] as Map? ?? {}).forEach((k, v) {
        if (kPresets.any((p) => p.name == k)) themeStyles[k as String] = WStyle.fromJson(Map<String, dynamic>.from(v as Map));
      });
      overrides.clear();
      (j['overrides'] as Map? ?? {}).forEach((k, v) {
        overrides[k as String] = WStyle.fromJson(Map<String, dynamic>.from(v as Map));
      });
      use24h = j['use24h'] as bool? ?? true;
      metric = j['metric'] as bool? ?? true;
      city = j['city'] as String? ?? city;
      country = j['country'] as String? ?? country;
      lat = (j['lat'] as num?)?.toDouble() ?? lat;
      lon = (j['lon'] as num?)?.toDouble() ?? lon;
      githubUser = j['githubUser'] as String? ?? githubUser;
    } catch (_) {}
  }
}

/// Generic JSON store for widget data (tasks, habits, notes...). Autosaves.
class Store extends ChangeNotifier {
  Map<String, dynamic> _d = {};
  Timer? _save;

  bool has(String k) => _d.containsKey(k);
  Object? raw(String k) => _d[k];

  String str(String k, [String def = '']) => _d[k] is String ? _d[k] as String : def;
  bool flag(String k, [bool def = false]) => _d[k] is bool ? _d[k] as bool : def;
  num n(String k, [num def = 0]) => _d[k] is num ? _d[k] as num : def;

  List<Map<String, dynamic>> list(String k) {
    final v = _d[k];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> strs(String k) {
    final v = _d[k];
    if (v is! List) return [];
    return v.map((e) => e.toString()).toList();
  }

  Map<String, dynamic> map(String k) {
    final v = _d[k];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  void set(String k, Object? v) {
    if (v == null) {
      _d.remove(k);
    } else {
      _d[k] = v;
    }
    notifyListeners();
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Sets a default only if the key does not exist yet.
  void seed(String k, Object v) {
    if (!_d.containsKey(k)) _d[k] = v;
  }

  void flush() => _prefs.setString('store', jsonEncode(_d));

  void load() {
    final raw = _prefs.getString('store');
    if (raw == null) return;
    try {
      _d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
  }

  void reset() {
    _d = {};
    flush();
    notifyListeners();
  }
}

/// Cached network data with TTL. Values are JSON-like and persisted for offline use.
class Hub extends ChangeNotifier {
  final Map<String, Object?> _data = {};
  final Map<String, DateTime> _at = {};
  final Map<String, String> _err = {};
  final Set<String> _busy = {};
  final Map<String, Future<void>> _pending = {};
  Timer? _save;

  T? get<T>(String k) {
    final v = _data[k];
    return v is T ? v : null;
  }

  String? error(String k) => _err[k];
  bool busy(String k) => _busy.contains(k);

  /// True when no request is in flight.
  bool get idle => _busy.isEmpty;
  DateTime? updated(String k) => _at[k];

  Future<void> ensure(String k, Duration ttl, Future<Object?> Function() fetch) {
    if (_busy.contains(k)) return _pending[k] ?? Future.value();
    final at = _at[k];
    if (at != null && DateTime.now().difference(at) < ttl) return Future.value();
    _busy.add(k);
    _at[k] = DateTime.now();
    final task = Future<void>(() async {
      try {
        final v = await fetch();
        _data[k] = v;
        _err.remove(k);
        _persist();
      } catch (e) {
        _err[k] = e.toString().replaceFirst('Exception: ', '');
        // retry sooner after a failure
        _at[k] = DateTime.now().subtract(ttl).add(const Duration(seconds: 45));
      } finally {
        _busy.remove(k);
        _pending.remove(k);
        notifyListeners();
      }
    });
    _pending[k] = task;
    // Let watchers show a busy state.
    scheduleMicrotask(notifyListeners);
    return task;
  }

  Future<void> settle() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.values.toList());
    }
  }

  Future<void> flush() async {
    _save?.cancel();
    try {
      await _prefs.setString('hub', jsonEncode(_data));
      await _prefs.setString('hub.at', jsonEncode(_at.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch))));
    } catch (e) {
      debugPrint('Hub.flush: $e');
    }
  }

  /// Inserts a value directly (used by tests and previews).
  @visibleForTesting
  void put(String k, Object? v) {
    _data[k] = v;
    _at[k] = DateTime.now();
  }

  void invalidate(String k) {
    _at.remove(k);
    notifyListeners();
  }

  void invalidateAll() {
    _at.clear();
    notifyListeners();
  }

  void _persist() {
    _save?.cancel();
    _save = Timer(const Duration(seconds: 1), () {
      try {
        flush();
      } catch (_) {}
    });
  }

  void load() {
    final raw = _prefs.getString('hub');
    if (raw == null) return;
    try {
      _data.addAll(Map<String, Object?>.from(jsonDecode(raw) as Map));
      final times = jsonDecode(_prefs.getString('hub.at') ?? '{}') as Map;
      for (final e in times.entries) {
        _at[e.key as String] = DateTime.fromMillisecondsSinceEpoch((e.value as num).toInt());
      }
    } catch (_) {}
  }

  void reset() {
    _data.clear();
    _at.clear();
    _prefs.remove('hub');
    _prefs.remove('hub.at');
    notifyListeners();
  }
}

/// Decoded images kept in memory, so widgets render synchronously (also offscreen).
class Pix extends ChangeNotifier {
  final Map<String, ui.Image> _img = {};
  final Set<String> _loading = {};

  ui.Image? get(String key, Future<Uint8List> Function() load) {
    final i = _img[key];
    if (i != null) return i;
    if (_loading.add(key)) {
      Future(() async {
        try {
          final bytes = await load();
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 900);
          final fr = await codec.getNextFrame();
          _img[key] = fr.image;
          notifyListeners();
        } catch (_) {
          Timer(const Duration(minutes: 1), () => _loading.remove(key));
        }
      });
    }
    return null;
  }
}

class Clock {
  final second = ValueNotifier<DateTime>(DateTime.now());
  final minute = ValueNotifier<DateTime>(DateTime.now());
  final List<VoidCallback> _onSecond = [];
  Timer? _t;

  void onSecond(VoidCallback f) => _onSecond.add(f);

  void start() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      second.value = now;
      if (now.minute != minute.value.minute || now.hour != minute.value.hour) {
        minute.value = now;
      }
      for (final f in _onSecond) {
        f();
      }
    });
  }
}

/// Battery level, charging state and a rough time-left estimate.
class Power extends ChangeNotifier {
  final _battery = Battery();
  int level = 0;
  BatteryState state = BatteryState.unknown;
  bool available = false;
  final List<(DateTime, int)> _samples = [];
  List<int> history = [];

  bool get charging => state == BatteryState.charging || state == BatteryState.full;

  /// Estimated minutes until full (charging) or empty (discharging).
  int? get minutesLeft {
    if (state == BatteryState.full || level >= 100 && charging) return 0;
    double? perPct;
    final rel = _samples.where((s) => DateTime.now().difference(s.$1).inMinutes < 40).toList();
    if (rel.length >= 2) {
      final d = (rel.last.$2 - rel.first.$2).abs();
      final mins = rel.last.$1.difference(rel.first.$1).inSeconds / 60;
      if (d >= 2 && mins > 0) perPct = mins / d;
    }
    perPct ??= charging ? 1.3 : 9.0;
    final left = charging ? (100 - level) * perPct : level * perPct;
    return left.round();
  }

  Future<void> init(Store store) async {
    history = store.strs('power.hist').map((e) => int.tryParse(e) ?? 0).toList();
    try {
      level = await _battery.batteryLevel;
      state = await _battery.batteryState;
      available = true;
      _samples.add((DateTime.now(), level));
      _battery.onBatteryStateChanged.listen((s) {
        if (s != state) _samples.clear();
        state = s;
        notifyListeners();
      });
    } catch (_) {
      available = false;
    }
    Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final l = await _battery.batteryLevel;
        if (l != level) {
          level = l;
          _samples.add((DateTime.now(), l));
          if (_samples.length > 60) _samples.removeAt(0);
          notifyListeners();
        }
      } catch (_) {}
    });
    Timer.periodic(const Duration(minutes: 10), (_) {
      history.add(level);
      if (history.length > 72) history.removeAt(0);
      store.set('power.hist', history.map((e) => '$e').toList());
    });
    notifyListeners();
  }
}

class AppState {
  final settings = Settings();
  final store = Store();
  final hub = Hub();
  final pix = Pix();
  final clock = Clock();
  final power = Power();

  late final Listenable listen =
      Listenable.merge([settings, store, hub, pix, clock.minute, power]);

  Future<void> init({bool background = false}) async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
    settings.load();
    store.load();
    hub.load();
    if (!background) {
      clock.start();
      await power.init(store);
    }
  }

  Future<void> resetAll() async {
    await _prefs.remove('store');
    store.reset();
    hub.reset();
  }
}

final app = AppState();
