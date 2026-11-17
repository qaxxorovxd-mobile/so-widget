import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/api.dart';
import '../core/state.dart';

/// Weather snapshot from Open-Meteo, shared by several widgets.
class Wx {
  Wx(this.j);
  final Map<String, dynamic> j;

  static String get key {
    final s = app.settings;
    return 'wx:${s.lat.toStringAsFixed(2)},${s.lon.toStringAsFixed(2)}:${s.metric}';
  }

  static Wx? get now {
    final s = app.settings;
    app.hub.ensure(key, const Duration(minutes: 5), () => Api.weather(s.lat, s.lon, s.metric));
    final d = app.hub.get<Map<String, dynamic>>(key);
    return d == null ? null : Wx(d);
  }

  Map<String, dynamic> get _cur => Map<String, dynamic>.from(j['current'] as Map);
  Map<String, dynamic> get _daily => Map<String, dynamic>.from(j['daily'] as Map);
  Map<String, dynamic> get _hourly => Map<String, dynamic>.from(j['hourly'] as Map);

  int get offset => (j['utc_offset_seconds'] as num?)?.toInt() ?? 0;

  /// "Now" expressed in the location's wall clock (as a UTC-flagged DateTime).
  DateTime get localNow => DateTime.now().toUtc().add(Duration(seconds: offset));

  static DateTime parse(String s) => DateTime.parse('${s}Z');

  int get temp => (_cur['temperature_2m'] as num).round();
  int get feels => (_cur['apparent_temperature'] as num).round();
  int get humidity => (_cur['relative_humidity_2m'] as num? ?? 0).round();
  double get wind => (_cur['wind_speed_10m'] as num? ?? 0).toDouble();
  int get code => (_cur['weather_code'] as num? ?? 0).toInt();
  bool get isDay => (_cur['is_day'] as num? ?? 1) == 1;

  List<int> _ints(Map<String, dynamic> m, String k) =>
      ((m[k] as List?) ?? []).map((e) => (e as num? ?? 0).round()).toList();

  List<int> get dMax => _ints(_daily, 'temperature_2m_max');
  List<int> get dMin => _ints(_daily, 'temperature_2m_min');
  List<int> get dCode => _ints(_daily, 'weather_code');
  List<int> get dRain => _ints(_daily, 'precipitation_probability_max');
  List<DateTime> get dDays =>
      ((_daily['time'] as List?) ?? []).map((e) => DateTime.parse(e as String)).toList();
  List<DateTime> get sunrise =>
      ((_daily['sunrise'] as List?) ?? []).map((e) => parse(e as String)).toList();
  List<DateTime> get sunset =>
      ((_daily['sunset'] as List?) ?? []).map((e) => parse(e as String)).toList();
  double get uv => ((_daily['uv_index_max'] as List?)?.first as num? ?? 0).toDouble();

  List<DateTime> get hTimes =>
      ((_hourly['time'] as List?) ?? []).map((e) => parse(e as String)).toList();
  List<int> get hTemp => _ints(_hourly, 'temperature_2m');
  List<int> get hRain => _ints(_hourly, 'precipitation_probability');

  /// Index of the current hour in hourly arrays.
  int get hourIndex {
    final now = localNow;
    final t = hTimes;
    for (var i = 0; i < t.length; i++) {
      if (t[i].isAfter(now)) return (i - 1).clamp(0, t.length - 1);
    }
    return 0;
  }

  /// ("rain", "next 2 hrs") style phrase.
  (String, String) get rainPhrase {
    if (code >= 51 && code <= 99) return (wmo(code).$1.toLowerCase(), 'right now');
    final i0 = hourIndex;
    final r = hRain;
    for (var i = i0 + 1; i < r.length && i < i0 + 24; i++) {
      if (r[i] >= 50) {
        final h = i - i0;
        return ('rain', 'in $h hr${h > 1 ? 's' : ''}');
      }
    }
    return ('dry', 'next 24 hrs');
  }
}

(String, IconData) wmo(int code, {bool day = true}) {
  if (code == 0) {
    return (day ? 'Clear' : 'Clear night', day ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill);
  }
  if (code <= 2) {
    return ('Partly cloudy', day ? CupertinoIcons.cloud_sun_fill : CupertinoIcons.cloud_moon_fill);
  }
  if (code == 3) return ('Overcast', CupertinoIcons.cloud_fill);
  if (code <= 48) return ('Fog', CupertinoIcons.cloud_fog_fill);
  if (code <= 57) return ('Drizzle', CupertinoIcons.cloud_drizzle_fill);
  if (code <= 67) return ('Rain', CupertinoIcons.cloud_rain_fill);
  if (code <= 77) return ('Snow', CupertinoIcons.snow);
  if (code <= 82) return ('Showers', CupertinoIcons.cloud_heavyrain_fill);
  if (code <= 86) return ('Snow showers', CupertinoIcons.cloud_snow_fill);
  return ('Thunderstorm', CupertinoIcons.cloud_bolt_rain_fill);
}

/// Moon phase math (no network needed).
class Moon {
  static const syn = 29.530588853;

  static double age(DateTime t) {
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    final days = t.toUtc().difference(ref).inSeconds / 86400;
    var a = days % syn;
    if (a < 0) a += syn;
    return a;
  }

  static double phase(DateTime t) => age(t) / syn;

  static double illumination(DateTime t) {
    final p = phase(t);
    return (1 - math.cos(2 * math.pi * p)) / 2;
  }

  static String name(double p) {
    if (p < 0.02 || p > 0.98) return 'New Moon';
    if (p < 0.23) return 'Waxing Crescent';
    if (p < 0.27) return 'First Quarter';
    if (p < 0.48) return 'Waxing Gibbous';
    if (p < 0.52) return 'Full Moon';
    if (p < 0.73) return 'Waning Gibbous';
    if (p < 0.77) return 'Last Quarter';
    return 'Waning Crescent';
  }

  static DateTime next(DateTime t, double target) {
    final p = phase(t);
    var d = (target - p) % 1;
    if (d < 0.01) d += 1;
    return t.add(Duration(minutes: (d * syn * 1440).round()));
  }
}
