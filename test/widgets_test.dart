import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_widget/core/registry.dart';
import 'package:so_widget/core/state.dart';
import 'package:so_widget/core/style.dart';
import 'package:so_widget/ui/kit.dart';
import 'package:so_widget/widgets/common.dart';

String _iso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}';

void fakeData() {
  final now = DateTime.now();
  final day0 = DateTime(now.year, now.month, now.day);
  app.hub.put(Wx.key, {
    'utc_offset_seconds': now.timeZoneOffset.inSeconds,
    'current': {
      'temperature_2m': 12.4,
      'apparent_temperature': 9.1,
      'relative_humidity_2m': 61,
      'weather_code': 3,
      'wind_speed_10m': 11.2,
      'is_day': 1,
    },
    'hourly': {
      'time': [for (var i = 0; i < 168; i++) _iso(day0.add(Duration(hours: i)))],
      'temperature_2m': [for (var i = 0; i < 168; i++) 8 + (i % 24) / 3],
      'precipitation_probability': [for (var i = 0; i < 168; i++) i % 24 == 18 ? 70 : 10],
      'weather_code': [for (var i = 0; i < 168; i++) 3],
    },
    'daily': {
      'time': [for (var i = 0; i < 7; i++) _iso(day0.add(Duration(days: i))).substring(0, 10)],
      'weather_code': [3, 61, 0, 2, 95, 71, 1],
      'temperature_2m_max': [14, 12, 16, 15, 11, 5, 9],
      'temperature_2m_min': [6, 5, 7, 8, 3, -2, 1],
      'sunrise': [for (var i = 0; i < 7; i++) _iso(day0.add(Duration(days: i, hours: 7, minutes: 12)))],
      'sunset': [for (var i = 0; i < 7; i++) _iso(day0.add(Duration(days: i, hours: 16, minutes: 58)))],
      'uv_index_max': [2.1, 1, 3, 2, 1, 1, 2],
      'precipitation_probability_max': [10, 80, 0, 20, 90, 60, 10],
    },
  });
  final s = app.settings;
  app.hub.put('air:${s.lat.toStringAsFixed(2)},${s.lon.toStringAsFixed(2)}', {
    'current': {'us_aqi': 87, 'pm2_5': 28.3, 'pm10': 41, 'ozone': 52, 'nitrogen_dioxide': 18},
  });
  app.hub.put('net', {'ping': 23, 'mbps': 148.2, 'at': now.millisecondsSinceEpoch});
  app.hub.put('news', [
    for (var i = 0; i < 8; i++) {'t': 'A fairly long headline number $i about technology and design systems', 'u': 'https://x.com', 's': 120, 'by': 'pg'},
  ]);
  app.hub.put('iss', {'latitude': 41.2, 'longitude': 69.1, 'velocity': 27580.2, 'altitude': 418.3});
  app.hub.put('quakes', [
    for (var i = 0; i < 20; i++) {'m': 2.5 + i / 5, 'p': '120 km SW of Somewhere, Region $i', 't': now.millisecondsSinceEpoch, 'lat': -40.0 + i * 4, 'lon': -170.0 + i * 17},
  ]);
  final ids = app.store.strs('crypto.ids');
  app.hub.put('crypto:${ids.join(',')}', [
    for (final id in ids)
      {
        'symbol': id.substring(0, 3),
        'current_price': 68250.12,
        'price_change_percentage_24h': -1.82,
        'sparkline_in_7d': {'price': [for (var i = 0; i < 168; i++) 60000 + (i * 37 % 900) * 10.0]},
      },
  ]);
  app.hub.put('fx:USD', {
    'rates': {'UZS': 12850.5, 'EUR': 0.92, 'RUB': 92.4, 'KZT': 488.1, 'GBP': 0.79},
    'time_last_update_utc': 'Tue, 17 Nov 2026 00:02:31 +0000',
  });
  final syms = app.store.strs('stocks');
  app.hub.put('stocks:${syms.join(',')}', [
    for (final sy in syms) {'s': sy, 'o': 180.2, 'h': 186.0, 'l': 179.1, 'c': 184.7},
  ]);
  app.hub.put('gh:${s.githubUser}', {
    'total': 1834,
    'repos': 7,
    'followers': 230000,
    'name': 'Linus Torvalds',
    'days': [
      for (var i = 370; i >= -10; i--) {'d': dkey(now.subtract(Duration(days: i))), 'c': i % 5, 'l': i % 5},
    ],
  });
  final servers = app.store.list('servers').map((e) => '${e['u']}').toList();
  app.hub.put('servers:${servers.join('|')}', [
    for (final u in servers) {'host': Uri.parse(u).host, 'code': 200, 'ms': 142, 'ok': true, 'ssl': 64, 'metrics': {'cpu': 34, 'ram': 71}},
  ]);
  final sites = app.store.strs('sites');
  app.hub.put('sites:${sites.join('|')}', [
    for (final u in sites) {'host': u, 'code': 200, 'ms': 88, 'ok': true, 'ssl': 9},
  ]);
  final repos = app.store.strs('repos');
  app.hub.put('repos:${repos.join(',')}', [
    for (final r in repos) {'r': r, 'tag': 'v3.50.0-stable', 'at': now.subtract(const Duration(days: 2)).toIso8601String()},
  ]);
  app.store.set('clips', ['Copied text example', 'https://qaxxorov.uz', 'Another snippet that is a bit longer than the rest']);
  app.store.set('sleep', [
    for (var i = 6; i >= 0; i--) {'d': dkey(now.subtract(Duration(days: i))), 'bed': '23:${10 + i}', 'wake': '07:0$i'},
  ]);
  app.store.set('mood', {for (var i = 0; i < 7; i++) dkey(now.subtract(Duration(days: i))): i % 5});
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    useGoogleFonts = false;
    final segoe = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (segoe.existsSync()) {
      final loader = FontLoader('TestSans');
      for (final f in [r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\seguisb.ttf', r'C:\Windows\Fonts\segoeuib.ttf']) {
        if (File(f).existsSync()) loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
      fallbackFontFamily = 'TestSans';
    }
    await app.init();
    seedAll(app.store);
  });

  test('registry has 56 unique widgets numbered 1..56', () {
    expect(allWidgets.length, 56);
    expect(allWidgets.map((w) => w.id).toSet().length, 56);
    expect(allWidgets.map((w) => w.no).toList(), List.generate(56, (i) => i + 1));
  });

  for (final withData in [false, true]) {
    for (final preset in [kPresets.first, kPresets[2]]) {
      testWidgets('all faces render (${withData ? 'data' : 'empty'}, ${preset.name})', (tester) async {
        if (withData) fakeData();
        app.settings.global = preset.style;
        final failures = <String>[];
        for (final def in allWidgets) {
          for (final size in WSize.values) {
            await tester.pumpWidget(MaterialApp(
              home: Center(child: WidgetFace(def, size, live: false)),
            ));
            final err = tester.takeException();
            if (err != null) failures.add('${def.id} @ ${size.name}: ${err.toString().split('\n').first}');
          }
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 3));
      });
    }
  }

  // Real home-screen cell sizes (dp): every widget must adapt to all of them.
  const cells = {
    '1x1': Size(80, 80),
    '2x1': Size(170, 80),
    '3x1': Size(260, 80),
    '4x1': Size(360, 80),
    '1x2': Size(80, 170),
    '2x2': Size(170, 170),
    '2x3': Size(170, 260),
    '3x2': Size(260, 170),
    '3x3': Size(260, 260),
    '4x2': Size(360, 170),
    '4x3': Size(360, 260),
    '4x4': Size(360, 380),
  };

  test('render plans keep the widget aspect ratio', () {
    for (final e in cells.entries) {
      final p = planFor(e.value.width, e.value.height);
      expect((p.logical.aspectRatio - e.value.aspectRatio).abs(), lessThan(0.01), reason: '${e.key} -> $p');
    }
    expect(planFor(170, 80).strip, isTrue);
    expect(planFor(360, 170).size, WSize.medium);
    expect(planFor(360, 380).size, WSize.large);
  });

  for (final big in [false, true]) {
    testWidgets('all faces render at every home-screen size${big ? ' (large text, heavy)' : ''}', (tester) async {
      fakeData();
      app.settings.global = big
          ? kPresets.first.style.copyWith(textScale: 1.15, weight: 2, compact: true, bgOpacity: 0.5, borderWidth: 3)
          : kPresets.first.style;
      final failures = <String>[];
      for (final def in allWidgets) {
        for (final e in cells.entries) {
          await tester.pumpWidget(MaterialApp(
            home: Center(child: FittedBox(child: WidgetFace(def, WSize.small, live: false, dims: e.value))),
          ));
          final err = tester.takeException();
          if (err != null) failures.add('${def.id} @ ${e.key}: ${err.toString().split('\n').first}');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 3));
    });
  }
}
