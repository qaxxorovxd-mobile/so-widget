import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Keyless public data sources used by the widgets.
class Api {
  static const _ua = {'User-Agent': 'SoWidget/1.0 (+https://qaxxorov.uz)'};

  static Future<dynamic> json(String url, {Map<String, String>? headers}) async {
    final r = await http
        .get(Uri.parse(url), headers: {..._ua, ...?headers})
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<dynamic> weather(double lat, double lon, bool metric) => json(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day'
        '&hourly=temperature_2m,precipitation_probability,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max'
        '&timezone=auto&forecast_days=7${metric ? '' : '&temperature_unit=fahrenheit&wind_speed_unit=mph'}',
      );

  static Future<dynamic> air(double lat, double lon) => json(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon'
        '&current=us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide&timezone=auto',
      );

  static Future<List<Map<String, dynamic>>> geocode(String q) async {
    final j = await json(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(q)}&count=8&language=en',
    );
    final r = (j['results'] as List?) ?? [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<dynamic> prayer(double lat, double lon, int method, int school) {
    final d = DateTime.now();
    return json(
      'https://api.aladhan.com/v1/timings/${d.day}-${d.month}-${d.year}'
      '?latitude=$lat&longitude=$lon&method=$method&school=$school',
    );
  }

  static Future<dynamic> crypto(List<String> ids) => json(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd'
        '&ids=${ids.join(',')}&sparkline=true&price_change_percentage=24h',
      );

  static Future<dynamic> currency(String base) =>
      json('https://open.er-api.com/v6/latest/$base');

  static Future<List<Map<String, dynamic>>> stocks(List<String> symbols) async {
    final s = symbols.map((e) => '${e.toLowerCase()}.us').join('+');
    final r = await http
        .get(Uri.parse('https://stooq.com/q/l/?s=$s&f=sd2t2ohlcv&h&e=csv'), headers: _ua)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    final lines = const LineSplitter().convert(r.body).skip(1);
    final out = <Map<String, dynamic>>[];
    for (final l in lines) {
      final p = l.split(',');
      if (p.length < 7) continue;
      final open = double.tryParse(p[3]);
      final close = double.tryParse(p[6]);
      if (open == null || close == null) continue;
      out.add({
        's': p[0].replaceAll('.US', '').replaceAll('.us', ''),
        'o': open,
        'h': double.tryParse(p[4]) ?? close,
        'l': double.tryParse(p[5]) ?? close,
        'c': close,
      });
    }
    if (out.isEmpty) throw Exception('No quotes');
    return out;
  }

  static Future<dynamic> github(String user) async {
    final cal = await json('https://github-contributions-api.jogruber.de/v4/$user?y=last');
    Map<String, dynamic> profile = {};
    try {
      profile = Map<String, dynamic>.from(await json('https://api.github.com/users/$user') as Map);
    } catch (_) {}
    final days = ((cal['contributions'] as List?) ?? [])
        .map((e) => {'d': e['date'], 'c': e['count'], 'l': e['level']})
        .toList();
    return {
      'total': (cal['total'] as Map?)?['lastYear'] ?? 0,
      'days': days,
      'repos': profile['public_repos'],
      'followers': profile['followers'],
      'name': profile['name'] ?? user,
    };
  }

  static Future<List<Map<String, dynamic>>> releases(List<String> repos) async {
    final out = <Map<String, dynamic>>[];
    await Future.wait(repos.map((r) async {
      try {
        final j = await json('https://api.github.com/repos/$r/releases/latest');
        out.add({'r': r, 'tag': j['tag_name'] ?? j['name'], 'at': j['published_at']});
      } catch (_) {
        try {
          final t = await json('https://api.github.com/repos/$r/tags?per_page=1') as List;
          if (t.isNotEmpty) out.add({'r': r, 'tag': t.first['name'], 'at': null});
        } catch (_) {}
      }
    }));
    if (out.isEmpty) throw Exception('No releases');
    out.sort((a, b) => (b['at'] ?? '').toString().compareTo((a['at'] ?? '').toString()));
    return out;
  }

  static Future<List<Map<String, dynamic>>> news() async {
    final ids = (await json('https://hacker-news.firebaseio.com/v0/topstories.json') as List)
        .take(8)
        .toList();
    final items = await Future.wait(ids.map((id) async {
      try {
        final j = await json('https://hacker-news.firebaseio.com/v0/item/$id.json');
        return {'t': j['title'], 'u': j['url'], 's': j['score'], 'by': j['by']};
      } catch (_) {
        return null;
      }
    }));
    return items.whereType<Map<String, dynamic>>().toList();
  }

  static Future<dynamic> iss() => json('https://api.wheretheiss.at/v1/satellites/25544');

  static Future<List<Map<String, dynamic>>> quakes() async {
    final j = await json(
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson',
    );
    final f = (j['features'] as List?) ?? [];
    return f.map((e) {
      final p = e['properties'];
      final c = e['geometry']['coordinates'] as List;
      return {
        'm': (p['mag'] as num?)?.toDouble() ?? 0,
        'p': p['place'] ?? 'Unknown',
        't': p['time'],
        'lon': (c[0] as num).toDouble(),
        'lat': (c[1] as num).toDouble(),
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> translate(String text, String from, String to) async {
    final pair = '${from == 'auto' ? 'Autodetect' : from}|$to';
    final j = await json(
      'https://api.mymemory.translated.net/get?q=${Uri.encodeQueryComponent(text)}&langpair=$pair',
    );
    final out = j['responseData']?['translatedText'] as String?;
    if (out == null || (j['responseStatus'] is num && j['responseStatus'] >= 400)) {
      if (from == 'auto') return translate(text, 'en', to);
      throw Exception(j['responseDetails'] ?? 'Translation failed');
    }
    return {
      'out': out,
      'detected': j['responseData']?['detectedLanguage'] ?? (from == 'auto' ? '' : from),
    };
  }

  /// Times an HTTP request; also reads the TLS certificate expiry.
  static Future<Map<String, dynamic>> probe(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final sw = Stopwatch()..start();
    try {
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', _ua['User-Agent']!);
      final res = await req.close().timeout(const Duration(seconds: 12));
      final ms = sw.elapsedMilliseconds;
      final body = await res.transform(utf8.decoder).join().timeout(
            const Duration(seconds: 8),
            onTimeout: () => '',
          );
      Map<String, dynamic>? metrics;
      try {
        final j = jsonDecode(body);
        if (j is Map) {
          metrics = {};
          for (final k in ['cpu', 'ram', 'memory', 'disk', 'uptime', 'status']) {
            if (j[k] != null) metrics[k] = j[k];
          }
          if (metrics.isEmpty) metrics = null;
        }
      } catch (_) {}
      final cert = res.certificate;
      return {
        'host': uri.host,
        'code': res.statusCode,
        'ms': ms,
        'ok': res.statusCode < 400,
        'ssl': cert?.endValidity.difference(DateTime.now()).inDays,
        'metrics': ?metrics,
      };
    } catch (e) {
      return {'host': uri.host, 'code': 0, 'ms': sw.elapsedMilliseconds, 'ok': false};
    } finally {
      client.close(force: true);
    }
  }

  /// Ping (avg of 3) + small download speed sample.
  static Future<Map<String, dynamic>> speed() async {
    final pings = <int>[];
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 6));
      pings.add(sw.elapsedMilliseconds);
    }
    double mbps = 0;
    try {
      final sw = Stopwatch()..start();
      final r = await http
          .get(Uri.parse('https://speed.cloudflare.com/__down?bytes=4000000'))
          .timeout(const Duration(seconds: 20));
      final secs = sw.elapsedMilliseconds / 1000;
      if (r.statusCode < 400 && secs > 0 && r.bodyBytes.isNotEmpty) mbps = r.bodyBytes.length * 8 / 1e6 / secs;
    } catch (_) {}
    pings.sort();
    return {
      'ping': pings[pings.length ~/ 2],
      'mbps': mbps,
      'at': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
