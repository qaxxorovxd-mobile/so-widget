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

  /// Exchange rates for [base]. Uses the Central Bank of Uzbekistan's official daily rates
  /// (what Uzbek banks and Google show for UZS), falling back to a daily market feed.
  static Future<dynamic> currency(String base) async {
    final b = base.toUpperCase();
    final rates = <String, double>{};
    var source = '';
    var date = '';
    try {
      final list = await json('https://cbu.uz/uz/arkhiv-kursov-valyut/json/') as List;
      // UZS for one unit of each currency.
      final uzsPer = <String, double>{'UZS': 1};
      for (final e in list) {
        final ccy = '${e['Ccy']}'.toUpperCase();
        final rate = double.tryParse('${e['Rate']}'.replaceAll(',', '.'));
        final nominal = double.tryParse('${e['Nominal']}') ?? 1;
        if (rate != null && nominal > 0) uzsPer[ccy] = rate / nominal;
        if (date.isEmpty) date = '${e['Date']}';
      }
      final baseUzs = uzsPer[b];
      if (baseUzs != null) {
        uzsPer.forEach((k, v) => rates[k] = baseUzs / v);
        source = 'Central Bank of Uzbekistan';
      }
    } catch (_) {}
    try {
      // Fills currencies the CBU doesn't list (and everything if the CBU is unreachable).
      final j = await json('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${b.toLowerCase()}.json');
      final m = Map<String, dynamic>.from(j[b.toLowerCase()] as Map);
      m.forEach((k, v) {
        if (v is num) rates.putIfAbsent(k.toUpperCase(), () => v.toDouble());
      });
      if (source.isEmpty) {
        source = 'Market rates';
        date = '${j['date']}';
      }
    } catch (_) {}
    if (rates.isEmpty) throw Exception('No rates');
    // Shown as "dd.MM.yyyy" by the CBU; keep the old field the widget reads.
    return {'rates': rates, 'source': source, 'date': date, 'time_last_update_utc': 'Updated $date'};
  }

  /// Today's quote (ZenQuotes, no key).
  static Future<dynamic> quote() async {
    final j = await json('https://zenquotes.io/api/today') as List;
    final q = Map<String, dynamic>.from(j.first as Map);
    return {'q': '${q['q']}'.trim(), 'a': '${q['a']}'.trim()};
  }

  /// Merriam-Webster's Word of the Day (RSS).
  static Future<dynamic> wordOfDay() async {
    final r = await http
        .get(Uri.parse('https://www.merriam-webster.com/wotd/feed/rss2'), headers: _ua)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    final x = utf8.decode(r.bodyBytes);
    final item = x.substring(x.indexOf('<item>'));
    String strip(String s) => s
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#149;', '•')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final word = RegExp(r'<title><!\[CDATA\[(.*?)\]\]></title>').firstMatch(item)?.group(1) ?? '';
    final pos = RegExp(r'<em>(noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection|phrase)</em>')
            .firstMatch(item)
            ?.group(1) ??
        '';
    final pron = RegExp(r'\\([^\\]{2,40})\\').firstMatch(item)?.group(1) ?? '';
    // Paragraphs after the "noun<br />" line: first is the meaning, the one starting with "//" is an example.
    final paras = RegExp(r'<p>(.*?)</p>', dotAll: true).allMatches(item).map((m) => strip(m.group(1)!)).toList();
    // The headline paragraph wraps the meaning: "word • \pron\ • noun <p>Meaning…".
    var meaning = '';
    final head = paras.firstWhere((p) => pos.isNotEmpty && p.contains('• $pos'), orElse: () => '');
    if (head.isNotEmpty) {
      meaning = head.substring(head.indexOf('• $pos') + pos.length + 2).trim();
    }
    if (meaning.isEmpty) {
      meaning = paras.firstWhere(
        (p) => p.length > 20 && !p.startsWith('//') && !p.contains('Word of the Day') && !p.startsWith('Examples'),
        orElse: () => '',
      );
    }
    final example = paras.firstWhere((p) => p.startsWith('//'), orElse: () => '').replaceFirst('//', '').trim();
    if (word.isEmpty) throw Exception('No word');
    return {'w': word, 'pos': pos, 'pron': pron, 'def': meaning, 'ex': example};
  }

  /// Live US stock quotes from Yahoo Finance (keyless). Change is vs. the previous close, like Google.
  static Future<List<Map<String, dynamic>>> stocks(List<String> symbols) async {
    final out = <Map<String, dynamic>>[];
    await Future.wait(symbols.map((s) async {
      try {
        final j = await json(
          'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(s.toUpperCase())}?range=1d&interval=15m',
          headers: {'User-Agent': 'Mozilla/5.0 SoWidget/1.0'},
        );
        final m = Map<String, dynamic>.from(j['chart']['result'][0]['meta'] as Map);
        final price = (m['regularMarketPrice'] as num?)?.toDouble();
        final prev = ((m['chartPreviousClose'] ?? m['previousClose']) as num?)?.toDouble();
        if (price == null || prev == null || prev == 0) return;
        out.add({
          's': s.toUpperCase(),
          'o': prev,
          'h': (m['regularMarketDayHigh'] as num?)?.toDouble() ?? price,
          'l': (m['regularMarketDayLow'] as num?)?.toDouble() ?? price,
          'c': price,
        });
      } catch (_) {}
    }));
    if (out.isEmpty) throw Exception('No quotes');
    // Keep the user's order.
    out.sort((a, b) => symbols.indexWhere((x) => x.toUpperCase() == a['s']).compareTo(symbols.indexWhere((x) => x.toUpperCase() == b['s'])));
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

  /// Latest release per repo from GitHub's Atom feeds (no API key, no rate limit).
  static Future<List<Map<String, dynamic>>> releases(List<String> repos) async {
    final out = <Map<String, dynamic>>[];
    await Future.wait(repos.map((r) async {
      for (final feed in ['releases', 'tags']) {
        try {
          final res = await http
              .get(Uri.parse('https://github.com/$r/$feed.atom'), headers: _ua)
              .timeout(const Duration(seconds: 15));
          if (res.statusCode >= 400) continue;
          final x = utf8.decode(res.bodyBytes);
          final i = x.indexOf('<entry>');
          if (i < 0) continue;
          final e = x.substring(i);
          final title = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(e)?.group(1)?.trim();
          final at = RegExp(r'<updated>(.*?)</updated>').firstMatch(e)?.group(1);
          if (title == null || title.isEmpty) continue;
          out.add({'r': r, 'tag': title, 'at': at});
          return;
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
