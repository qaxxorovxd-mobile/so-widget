import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import '../ui/location.dart';
import 'lifestyle.dart' show dayIndex;
import 'productivity.dart' show openUrl;

void seedCreative(Store s) {
  s.seed('color.mode', 'daily');
  s.seed('color.seed', '#7CF29A');
  s.seed('wall.gray', true);
  s.seed('wall.shuffle', 0);
  s.seed('cards', [
    for (final p in const [
      ('serendipity', 'tasodifiy omad'),
      ('resilient', 'chidamli'),
      ('meticulous', 'sinchkov, puxta'),
      ('eloquent', 'notiq, ravon'),
      ('ephemeral', 'o‘tkinchi'),
      ('candid', 'samimiy, ochiq'),
      ('diligent', 'tirishqoq'),
      ('vivid', 'yorqin'),
      ('ubiquitous', 'hamma joyda mavjud'),
      ('pragmatic', 'amaliy'),
    ])
      {'f': p.$1, 'b': p.$2, 'box': 0, 'due': 0},
  ]);
  s.seed('qr', {'type': 'url', 'v': 'https://qaxxorov.uz'});
  s.seed('calc', {'expr': '12×8+4', 'res': '100'});
  s.seed('tr', {'src': 'Good morning', 'out': 'Xayrli tong', 'from': 'auto', 'to': 'uz', 'det': 'en'});
}

final creativeWidgets = <WDef>[
  WDef(
    no: 41,
    id: 'news',
    name: 'Minimal News',
    desc: 'A short, calm list of top tech stories.',
    cat: WCat.creative,
    icon: CupertinoIcons.news_solid,
    preferred: WSize.medium,
    face: _news,
    editor: (ctx) => const _NewsEditor(),
  ),
  WDef(
    no: 42,
    id: 'space',
    name: 'Space Live',
    desc: 'Live ISS position and the next sky event.',
    cat: WCat.creative,
    icon: CupertinoIcons.rocket_fill,
    preferred: WSize.medium,
    face: _space,
    editor: (ctx) => const RefreshRow('iss', label: 'Update ISS position'),
  ),
  WDef(
    no: 43,
    id: 'earth',
    name: 'Earth Events',
    desc: 'Earthquakes from the last 24 hours on a world map.',
    cat: WCat.creative,
    icon: CupertinoIcons.waveform_path,
    preferred: WSize.medium,
    face: _earth,
    editor: (ctx) => const RefreshRow('quakes'),
  ),
  WDef(
    no: 44,
    id: 'color',
    name: 'Color Studio',
    desc: 'HEX/RGB palettes from a seed color, or a new one daily.',
    cat: WCat.creative,
    icon: CupertinoIcons.paintbrush_fill,
    face: _color,
    editor: (ctx) => const _ColorEditor(),
  ),
  WDef(
    no: 45,
    id: 'wallpaper',
    name: 'Daily Wallpaper',
    desc: 'A fresh aesthetic photo every day.',
    cat: WCat.creative,
    icon: CupertinoIcons.photo_on_rectangle,
    face: _wallpaper,
    editor: (ctx) => const _WallEditor(),
  ),
  WDef(
    no: 46,
    id: 'word',
    name: 'Word of the Day',
    desc: 'A new English word with meaning and example.',
    cat: WCat.creative,
    icon: CupertinoIcons.textformat_abc,
    preferred: WSize.medium,
    face: _word,
  ),
  WDef(
    no: 47,
    id: 'cards',
    name: 'Language Cards',
    desc: 'Flashcards with spaced repetition.',
    cat: WCat.creative,
    icon: CupertinoIcons.rectangle_stack_fill,
    face: _cards,
    editor: (ctx) => const _CardsEditor(),
  ),
  WDef(
    no: 48,
    id: 'qr',
    name: 'QR Studio',
    desc: 'QR codes for links, Wi-Fi and text.',
    cat: WCat.creative,
    icon: CupertinoIcons.qrcode,
    face: _qr,
    editor: (ctx) => const _QrEditor(),
  ),
  WDef(
    no: 49,
    id: 'calc',
    name: 'Mini Calculator',
    desc: 'Quick math with your last result on the widget.',
    cat: WCat.creative,
    icon: CupertinoIcons.plus_slash_minus,
    face: _calc,
    editor: (ctx) => const _CalcPad(),
  ),
  WDef(
    no: 50,
    id: 'translate',
    name: 'Quick Translate',
    desc: 'Translate text with automatic language detection.',
    cat: WCat.creative,
    icon: CupertinoIcons.globe,
    preferred: WSize.medium,
    face: _translate,
    editor: (ctx) => const _TranslateEditor(),
  ),
];

Widget _loadingC(WCtx c, IconData i, String title, String key) =>
    WEmpty(c, i, app.hub.error(key) != null ? 'Couldn’t load. ${app.hub.error(key)}' : 'Loading…', title: title);

// ───────────────────────── 41 News ─────────────────────────

Widget _news(WCtx c) {
  app.hub.ensure('news', const Duration(minutes: 30), Api.news);
  final raw = app.hub.get<List>('news');
  if (raw == null) return _loadingC(c, CupertinoIcons.news, 'News', 'news');
  final items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final max = switch (c.size) { WSize.small => 2, WSize.medium => 3, WSize.large => 7 };
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.news_solid, 'Top stories', trailing: c.sm ? null : 'Hacker News'),
      const SizedBox(height: 4),
      for (var i = 0; i < math.min(max, items.length); i++)
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (!c.sm) SizedBox(width: 24, child: Text('${i + 1}', style: c.t(13, dim: true))),
            Expanded(
              child: Text('${items[i]['t']}',
                  maxLines: c.sm ? 3 : 2, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 13 : 15, w: FontWeight.w500, h: 1.2)),
            ),
          ]),
        ),
    ]),
  );
}

class _NewsEditor extends StatelessWidget {
  const _NewsEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.hub,
        builder: (context, _) {
          final items = (app.hub.get<List>('news') ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          return Column(children: [
            Section(
              title: 'Stories',
              footer: 'Tap to read. Updated every 30 minutes.',
              children: [
                for (final i in items)
                  RowItem(
                    title: '${i['t']}',
                    subtitle: '${i['s']} points · ${i['by']}',
                    onTap: i['u'] == null ? null : () => openUrl('${i['u']}'),
                  ),
              ],
            ),
            const RefreshRow('news'),
          ]);
        },
      );
}

// ───────────────────────── 42 Space Live ─────────────────────────

final List<(double, double)> _issTrail = [];

const _sky = [
  (1, 3, 'Quadrantids meteor shower'),
  (4, 22, 'Lyrids meteor shower'),
  (5, 6, 'Eta Aquariids meteor shower'),
  (7, 30, 'Delta Aquariids meteor shower'),
  (8, 12, 'Perseids meteor shower'),
  (10, 8, 'Draconids meteor shower'),
  (10, 21, 'Orionids meteor shower'),
  (11, 17, 'Leonids meteor shower'),
  (12, 14, 'Geminids meteor shower'),
  (12, 22, 'Ursids meteor shower'),
];

(String, DateTime) _nextSky() {
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  for (final y in [now.year, now.year + 1]) {
    for (final e in _sky) {
      final d = DateTime(y, e.$1, e.$2);
      if (!d.isBefore(t0)) return (e.$3, d);
    }
  }
  return ('', now);
}

Widget _space(WCtx c) {
  app.hub.ensure('iss', const Duration(seconds: 45), () async {
    final j = await Api.iss();
    return j;
  });
  final j = app.hub.get<Map<String, dynamic>>('iss');
  final sky = _nextSky();
  final days = sky.$2.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
  final skyText = days == 0 ? '${sky.$1} peaks tonight' : '${sky.$1} in $days days';
  if (j == null) return _loadingC(c, CupertinoIcons.rocket, 'Space Live', 'iss');
  final lat = (j['latitude'] as num).toDouble(), lon = (j['longitude'] as num).toDouble();
  if (_issTrail.isEmpty || _issTrail.last != (lat, lon)) {
    _issTrail.add((lat, lon));
    if (_issTrail.length > 60) _issTrail.removeAt(0);
  }
  final vel = (j['velocity'] as num? ?? 0).round();
  final alt = (j['altitude'] as num? ?? 0).round();
  String fmtC(double v, String p, String n) => '${v.abs().toStringAsFixed(1)}°${v >= 0 ? p : n}';
  final map = MapGrid(c, points: [(lat, lon, 0.25)], trail: _issTrail);
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.rocket_fill, 'ISS'),
        Expanded(child: map),
        Text('${fmtC(lat, 'N', 'S')} ${fmtC(lon, 'E', 'W')}', style: c.t(13)),
        Text('${groupNum(vel)} km/h', style: c.t(11, dim: true)),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: WHeader(c, CupertinoIcons.rocket_fill, 'ISS · live')),
        Text('${fmtC(lat, 'N', 'S')}  ${fmtC(lon, 'E', 'W')}', style: c.t(13)),
      ]),
      const SizedBox(height: 8),
      Expanded(child: map),
      const SizedBox(height: 8),
      Row(children: [
        Text('${groupNum(vel)} km/h', style: c.t(14)),
        Text('  ·  ${groupNum(alt)} km up', style: c.t(14, dim: true)),
        const Spacer(),
        if (c.md) Flexible(child: Text(sky.$1.split(' ').first, maxLines: 1, style: c.t(12, c: c.warm))),
      ]),
      if (c.lg) ...[
        Divider(color: c.line, height: 20),
        Row(children: [
          Icon(CupertinoIcons.sparkles, size: 16, color: c.warm),
          const SizedBox(width: 8),
          Expanded(child: Text(skyText, style: c.t(14))),
        ]),
      ],
    ]),
  );
}

// ───────────────────────── 43 Earth Events ─────────────────────────

Widget _earth(WCtx c) {
  app.hub.ensure('quakes', const Duration(minutes: 20), Api.quakes);
  final raw = app.hub.get<List>('quakes');
  if (raw == null) return _loadingC(c, CupertinoIcons.waveform_path, 'Earth Events', 'quakes');
  final qs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    ..sort((a, b) => (b['m'] as num).compareTo(a['m'] as num));
  final top = qs.isEmpty ? null : qs.first;
  final pts = qs.map((q) => ((q['lat'] as num).toDouble(), (q['lon'] as num).toDouble(), (((q['m'] as num) - 2.5) / 5).clamp(0.0, 1.0).toDouble())).toList();
  final map = MapGrid(c, points: pts);
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.waveform_path, '${qs.length} quakes'),
        Expanded(child: map),
        if (top != null) Text('M${(top['m'] as num).toStringAsFixed(1)} strongest', style: c.t(13)),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.waveform_path, 'Earthquakes · 24h', trailing: '${qs.length} events'),
      const SizedBox(height: 8),
      Expanded(child: map),
      const SizedBox(height: 8),
      for (final q in qs.take(c.lg ? 4 : 1))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: c.warm.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: Text('M${(q['m'] as num).toStringAsFixed(1)}', style: c.t(12, c: c.warm, glow: false)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('${q['p']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(13))),
            Text(ago(DateTime.fromMillisecondsSinceEpoch((q['t'] as num).toInt())), style: c.t(11, dim: true)),
          ]),
        ),
    ]),
  );
}

// ───────────────────────── 44 Color Studio ─────────────────────────

List<Color> palette() {
  final mode = app.store.str('color.mode', 'daily');
  Color seed = parseHex(app.store.str('color.seed', '#7CF29A')) ?? const Color(0xFF7CF29A);
  if (mode == 'daily') {
    final h = (dayIndex(360, 11) * 137.5) % 360;
    seed = HSLColor.fromAHSL(1, h, 0.62, 0.58).toColor();
  }
  final b = HSLColor.fromColor(seed);
  Color rot(double d, {double? l, double? s}) =>
      b.withHue((b.hue + d) % 360).withLightness((l ?? b.lightness).clamp(0.05, 0.95)).withSaturation((s ?? b.saturation).clamp(0.0, 1.0)).toColor();
  return switch (mode) {
    'complementary' => [rot(0, l: 0.25), rot(0), rot(0, l: 0.8), rot(180), rot(180, l: 0.3)],
    'triadic' => [rot(0), rot(120), rot(240), rot(0, l: 0.2), rot(0, l: 0.88)],
    'mono' => [rot(0, l: 0.15), rot(0, l: 0.32), rot(0), rot(0, l: 0.72), rot(0, l: 0.9)],
    _ => [rot(-40), rot(-20), rot(0), rot(20), rot(40)],
  };
}

String _rgb(Color c) => '${(c.r * 255).round()} ${(c.g * 255).round()} ${(c.b * 255).round()}';

Widget _color(WCtx c) {
  final p = palette();
  final mode = app.store.str('color.mode', 'daily');
  return WShell(
    c: c,
    padding: EdgeInsets.zero,
    child: Column(children: [
      Expanded(
        child: Row(children: [
          for (final col in p)
            Expanded(
              child: Container(
                color: col,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 10),
                child: c.sm
                    ? null
                    : RotatedBox(
                        quarterTurns: c.lg ? 3 : 0,
                        child: fit(
                          Text(hexOf(col).substring(1), style: c.mono(c.lg ? 14 : 11, c: col.computeLuminance() > 0.45 ? Colors.black87 : Colors.white, dim: false)),
                          a: Alignment.center,
                        ),
                      ),
              ),
            ),
        ]),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: c.sm ? 12 : 16, vertical: c.sm ? 10 : 12),
        child: Row(children: [
          Text(mode == 'daily' ? 'Today’s palette' : mode[0].toUpperCase() + mode.substring(1), style: c.t(c.sm ? 12 : 14)),
          const Spacer(),
          if (!c.sm) Text('RGB ${_rgb(p[2])}', style: c.mono(11)),
        ]),
      ),
    ]),
  );
}

class _ColorEditor extends StatelessWidget {
  const _ColorEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final p = palette();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: Seg<String>(
                value: app.store.str('color.mode', 'daily'),
                items: const {'daily': 'Daily', 'analogous': 'Analog', 'complementary': 'Compl.', 'triadic': 'Triadic', 'mono': 'Mono'},
                onChanged: (v) => app.store.set('color.mode', v),
              ),
            ),
            Section(
              title: 'Palette',
              footer: 'Tap a color to copy its HEX.',
              children: [
                for (final col in p)
                  RowItem(
                    icon: CupertinoIcons.circle_fill,
                    iconColor: col,
                    title: hexOf(col),
                    subtitle: 'RGB ${_rgb(col)}',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: hexOf(col)));
                      toast(context, '${hexOf(col)} copied');
                    },
                  ),
              ],
            ),
            Section(title: 'Seed', children: [
              RowItem(
                icon: CupertinoIcons.eyedropper,
                iconColor: parseHex(app.store.str('color.seed')) ?? Colors.grey,
                title: 'Seed color',
                value: app.store.str('color.seed'),
                onTap: () async {
                  final r = await promptText(context, 'Seed HEX', initial: app.store.str('color.seed'), placeholder: '#7CF29A');
                  if (r == null || parseHex(r) == null) return;
                  app.store.set('color.seed', hexOf(parseHex(r)!));
                  if (app.store.str('color.mode') == 'daily') app.store.set('color.mode', 'analogous');
                },
              ),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 45 Daily Wallpaper ─────────────────────────

String _wallUrl(WSize s) {
  final seed = '${dkey(DateTime.now())}-${app.store.n('wall.shuffle', 0)}';
  final gray = app.store.flag('wall.gray', true) ? '?grayscale' : '';
  return 'https://picsum.photos/seed/sowidget$seed/900/900$gray';
}

Widget _wallpaper(WCtx c) {
  final url = _wallUrl(c.size);
  final img = app.pix.get(url, () async {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    return r.bodyBytes;
  });
  final now = DateTime.now();
  return WShell(
    c: c,
    background: img == null
        ? Center(child: Icon(CupertinoIcons.photo, color: c.dim, size: 30))
        : Stack(fit: StackFit.expand, children: [
            RawImage(image: img, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.5)],
                ),
              ),
            ),
          ]),
    child: Stack(children: [
      if (!c.sm)
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: fit(
              Text(hm(now, app.settings.use24h), style: c.t(c.lg ? 140 : 110, w: FontWeight.w700, c: Colors.white.withValues(alpha: 0.42), glow: false, h: 1)),
              a: Alignment.centerRight,
            ),
          ),
        ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Text(kDays[now.weekday - 1], style: c.script(c.sm ? 30 : (c.lg ? 52 : 42), c: Colors.white)),
        Text('${now.day} ${kMonths[now.month - 1].toUpperCase()}', style: c.t(c.sm ? 12 : 17, w: FontWeight.w800, c: Colors.white, ls: 0.6)),
      ]),
    ]),
  );
}

class _WallEditor extends StatelessWidget {
  const _WallEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) => Section(
          footer: 'Photos from Lorem Picsum. A new one appears every day.',
          children: [
            SwitchRow('Black & white', app.store.flag('wall.gray', true), (v) => app.store.set('wall.gray', v)),
            RowItem(
              icon: CupertinoIcons.shuffle,
              iconColor: const Color(0xFF3A3A3C),
              title: 'Shuffle today’s photo',
              chevron: false,
              onTap: () => app.store.set('wall.shuffle', app.store.n('wall.shuffle', 0) + 1),
            ),
          ],
        ),
      );
}

// ───────────────────────── 46 Word of the Day ─────────────────────────

const _words = [
  ('Serendipity', 'noun', 'Finding something good without looking for it.', 'Meeting her was pure serendipity.'),
  ('Ephemeral', 'adjective', 'Lasting for a very short time.', 'Fame on the internet is often ephemeral.'),
  ('Luminous', 'adjective', 'Full of or giving off light; bright.', 'The city looked luminous after rain.'),
  ('Sonder', 'noun', 'Realizing each passerby has a life as vivid as your own.', 'Sonder hit him on the crowded train.'),
  ('Petrichor', 'noun', 'The pleasant smell of earth after rain.', 'The garden was full of petrichor.'),
  ('Halcyon', 'adjective', 'Calm, peaceful and happy, often in the past.', 'Those were halcyon summer days.'),
  ('Resilient', 'adjective', 'Able to recover quickly from difficulty.', 'Teams that learn fast are resilient.'),
  ('Meticulous', 'adjective', 'Showing great attention to detail.', 'Her design work is meticulous.'),
  ('Eloquent', 'adjective', 'Fluent and persuasive in speaking or writing.', 'He gave an eloquent speech.'),
  ('Ineffable', 'adjective', 'Too great to be expressed in words.', 'The view had an ineffable beauty.'),
  ('Quintessential', 'adjective', 'The most perfect example of something.', 'It is the quintessential city café.'),
  ('Ubiquitous', 'adjective', 'Present or found everywhere.', 'Smartphones are ubiquitous today.'),
  ('Pragmatic', 'adjective', 'Dealing with things sensibly and realistically.', 'We took a pragmatic approach.'),
  ('Candor', 'noun', 'The quality of being open and honest.', 'I appreciate your candor.'),
  ('Wanderlust', 'noun', 'A strong desire to travel.', 'Wanderlust took her to Samarkand.'),
  ('Equanimity', 'noun', 'Mental calmness, especially in difficulty.', 'She faced the news with equanimity.'),
  ('Panacea', 'noun', 'A solution for all problems.', 'Technology is not a panacea.'),
  ('Verdant', 'adjective', 'Green with grass or rich vegetation.', 'Verdant hills surrounded the village.'),
  ('Tenacious', 'adjective', 'Holding firmly; persistent.', 'A tenacious founder rarely gives up.'),
  ('Aesthetic', 'noun', 'A set of principles behind a style.', 'The app has a minimal aesthetic.'),
  ('Lucid', 'adjective', 'Expressed clearly; easy to understand.', 'The docs are short and lucid.'),
  ('Solitude', 'noun', 'The state of being alone, often pleasantly.', 'He found focus in solitude.'),
  ('Ardent', 'adjective', 'Very enthusiastic or passionate.', 'An ardent fan of good typography.'),
  ('Benevolent', 'adjective', 'Well meaning and kindly.', 'A benevolent mentor helped him.'),
  ('Cascade', 'noun', 'A series of things happening one after another.', 'A cascade of updates followed.'),
  ('Diligent', 'adjective', 'Showing care and effort in work.', 'Diligent practice beats talent.'),
  ('Euphoria', 'noun', 'A feeling of intense happiness.', 'Shipping the app brought euphoria.'),
  ('Gossamer', 'adjective', 'Very light, thin and delicate.', 'Gossamer clouds drifted by.'),
  ('Nuance', 'noun', 'A subtle difference in meaning or tone.', 'Good design lives in the nuance.'),
  ('Zenith', 'noun', 'The highest point reached.', 'The sun reached its zenith at noon.'),
];

Widget _word(WCtx c) {
  final w = _todayWord();
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 26 : (c.sm ? 16 : 20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!c.sm) WHeader(c, CupertinoIcons.textformat_abc, 'Word of the day', trailing: w.$2),
      if (c.sm) Text(w.$2, style: c.t(12, dim: true)),
      const Spacer(),
      fit(Text(w.$1, style: c.script(c.lg ? 64 : (c.sm ? 40 : 50)))),
      SizedBox(height: c.lg ? 10 : 4),
      Text(w.$3, maxLines: c.sm ? 3 : 2, overflow: TextOverflow.ellipsis, style: c.t(c.lg ? 18 : (c.sm ? 12 : 14), w: FontWeight.w500, h: 1.25)),
      if (c.lg) ...[
        const SizedBox(height: 14),
        Text('“${w.$4}”', style: c.t(16, dim: true, h: 1.3)),
      ],
      if (!c.sm) const Spacer(),
    ]),
  );
}

// ───────────────────────── 47 Language Cards ─────────────────────────

const _intervals = [0, 1, 3, 7, 14, 30];

List<Map<String, dynamic>> _due() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return app.store.list('cards').where((e) => (e['due'] as num? ?? 0) <= now).toList();
}

Widget _cards(WCtx c) {
  final all = app.store.list('cards');
  if (all.isEmpty) return WEmpty(c, CupertinoIcons.rectangle_stack, 'Add flashcards to learn.', title: 'Cards');
  final due = _due();
  final card = due.isNotEmpty ? due.first : all.first;
  final mastered = all.where((e) => (e['box'] as num? ?? 0) >= 4).length;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : (c.sm ? 16 : 18)),
    child: Stack(children: [
      if (!c.sm)
        Positioned(
          right: 0,
          bottom: 0,
          child: Text('${(card['box'] as num? ?? 0) + 1}', style: c.t(c.lg ? 160 : 96, c: c.faint, glow: false, h: 1)),
        ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.rectangle_stack_fill, due.isEmpty ? 'All caught up' : '${due.length} due', trailing: c.sm ? null : '$mastered/${all.length} mastered'),
        const Spacer(),
        fit(Text('${card['f']}', style: c.t(c.lg ? 46 : (c.sm ? 26 : 34), w: FontWeight.w600))),
        const SizedBox(height: 4),
        Text(due.isEmpty ? '${card['b']}' : 'Tap to review', style: c.t(c.sm ? 12 : 14, dim: true)),
        if (c.lg) ...[
          const SizedBox(height: 18),
          GlowBar(c, mastered / all.length, height: 8),
        ],
      ]),
    ]),
  );
}

class _CardsEditor extends StatefulWidget {
  const _CardsEditor();

  @override
  State<_CardsEditor> createState() => _CardsEditorState();
}

class _CardsEditorState extends State<_CardsEditor> {
  bool _show = false;

  void _grade(Map<String, dynamic> card, int g) {
    final all = app.store.list('cards');
    final i = all.indexWhere((e) => e['f'] == card['f'] && e['b'] == card['b']);
    if (i < 0) return;
    var box = (all[i]['box'] as num? ?? 0).toInt();
    box = g == 0 ? 0 : (box + g).clamp(0, _intervals.length - 1);
    all[i]['box'] = box;
    all[i]['due'] = DateTime.now().add(Duration(days: _intervals[box], minutes: g == 0 ? 1 : 0)).millisecondsSinceEpoch;
    app.store.set('cards', all);
    setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final due = _due();
          final all = app.store.list('cards');
          final card = due.isEmpty ? null : due.first;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: GestureDetector(
                onTap: () => setState(() => _show = true),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: ShapeDecoration(color: K.card, shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(24))),
                  padding: const EdgeInsets.all(20),
                  child: card == null
                      ? const Center(child: Text('Nothing due. Come back later ✨', style: TextStyle(color: K.label2, fontSize: 16)))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${card['f']}', style: const TextStyle(color: K.label, fontSize: 30, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _show ? 1 : 0.4,
                            child: Text(_show ? '${card['b']}' : 'Tap to reveal',
                                style: TextStyle(color: _show ? K.label : K.label2, fontSize: 18)),
                          ),
                        ]),
                ),
              ),
            ),
            if (card != null && _show)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                child: Row(children: [
                  Expanded(child: PillButton('Again', filled: false, onTap: () => _grade(card, 0))),
                  const SizedBox(width: 8),
                  Expanded(child: PillButton('Good', filled: false, onTap: () => _grade(card, 1))),
                  const SizedBox(width: 8),
                  Expanded(child: PillButton('Easy', onTap: () => _grade(card, 2))),
                ]),
              ),
            ListEditor(
              title: 'Deck · ${all.length} cards',
              items: all,
              titleOf: (m) => '${m['f']}',
              subtitleOf: (m) => '${m['b']}  ·  box ${(m['box'] as num? ?? 0) + 1}',
              addLabel: 'Add card',
              footer: 'Leitner spaced repetition: cards you know come back less often.',
              onAdd: () async {
                final r = await promptFields(context, title: 'New card', labels: ['Front (word)', 'Back (meaning)']);
                if (r == null || r[0].isEmpty) return;
                app.store.set('cards', [...all, {'f': r[0], 'b': r[1], 'box': 0, 'due': 0}]);
              },
              onDelete: (i) => app.store.set('cards', [...all]..removeAt(i)),
            ),
          ]);
        },
      );
}

// ───────────────────────── 48 QR Studio ─────────────────────────

String _qrData(Map<String, dynamic> q) => switch (q['type']) {
      'wifi' => 'WIFI:T:${q['sec'] ?? 'WPA'};S:${q['ssid'] ?? ''};P:${q['pass'] ?? ''};;',
      _ => '${q['v'] ?? ''}',
    };

String _qrLabel(Map<String, dynamic> q) => switch (q['type']) {
      'wifi' => '${q['ssid'] ?? 'Wi-Fi'}',
      'url' => (Uri.tryParse('${q['v']}')?.host.isNotEmpty ?? false) ? Uri.parse('${q['v']}').host : '${q['v']}',
      _ => '${q['v']}',
    };

Widget _qr(WCtx c) {
  final q = app.store.map('qr');
  final data = _qrData(q);
  if (data.isEmpty) return WEmpty(c, CupertinoIcons.qrcode, 'Create a QR code.', title: 'QR Studio');
  final code = QrImageView(
    data: data,
    version: QrVersions.auto,
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.fg),
    dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: c.fg),
  );
  final icon = q['type'] == 'wifi' ? CupertinoIcons.wifi : (q['type'] == 'url' ? CupertinoIcons.link : CupertinoIcons.text_alignleft);
  if (c.md) {
    return WShell(
      c: c,
      child: Row(children: [
        AspectRatio(aspectRatio: 1, child: code),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: c.fg, size: 22),
            const SizedBox(height: 8),
            Text(_qrLabel(q), maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(19, h: 1.1)),
            Text(q['type'] == 'wifi' ? 'Scan to join' : 'Scan to open', style: c.t(13, dim: true)),
          ]),
        ),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 30 : 16),
    child: Column(children: [
      Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: code))),
      SizedBox(height: c.lg ? 18 : 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: c.dim, size: c.lg ? 18 : 13),
        const SizedBox(width: 6),
        Flexible(child: Text(_qrLabel(q), maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.lg ? 17 : 12))),
      ]),
    ]),
  );
}

class _QrEditor extends StatelessWidget {
  const _QrEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final q = app.store.map('qr');
          void set(String k, Object v) {
            q[k] = v;
            app.store.set('qr', q);
          }

          final type = '${q['type'] ?? 'url'}';
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: Seg<String>(value: type, items: const {'url': 'Link', 'wifi': 'Wi-Fi', 'text': 'Text'}, onChanged: (v) => set('type', v)),
            ),
            if (type == 'wifi')
              Section(title: 'Wi-Fi', footer: 'Stored only on this device.', children: [
                RowItem(
                  title: 'Network name',
                  value: '${q['ssid'] ?? ''}',
                  onTap: () async {
                    final r = await promptText(context, 'Network name (SSID)', initial: '${q['ssid'] ?? ''}');
                    if (r != null) set('ssid', r);
                  },
                ),
                RowItem(
                  title: 'Password',
                  value: (q['pass'] ?? '').toString().isEmpty ? '' : '••••••',
                  onTap: () async {
                    final r = await promptText(context, 'Password', initial: '${q['pass'] ?? ''}');
                    if (r != null) set('pass', r);
                  },
                ),
                RowItem(
                  title: 'Security',
                  trailing: SizedBox(
                    width: 170,
                    child: Seg<String>(
                      value: '${q['sec'] ?? 'WPA'}',
                      items: const {'WPA': 'WPA', 'WEP': 'WEP', 'nopass': 'None'},
                      onChanged: (v) => set('sec', v),
                    ),
                  ),
                ),
              ])
            else
              Section(title: type == 'url' ? 'Link' : 'Text', children: [
                FieldRow(
                  key: ValueKey(type),
                  initial: '${q['v'] ?? ''}',
                  placeholder: type == 'url' ? 'https://' : 'Any text',
                  keyboard: type == 'url' ? TextInputType.url : TextInputType.multiline,
                  maxLines: type == 'url' ? 1 : 4,
                  onChanged: (v) => set('v', v),
                ),
              ]),
          ]);
        },
      );
}

// ───────────────────────── 49 Mini Calculator ─────────────────────────

class _Parser {
  _Parser(String s) : src = s.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '').replaceAll(',', '.');
  final String src;
  int i = 0;

  double parse() {
    final v = _expr();
    if (i < src.length) throw const FormatException('Unexpected');
    return v;
  }

  double _expr() {
    var v = _term();
    while (i < src.length && (src[i] == '+' || src[i] == '-')) {
      final op = src[i++];
      final r = _term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double _term() {
    var v = _pow();
    while (i < src.length && (src[i] == '*' || src[i] == '/' || src[i] == '%')) {
      final op = src[i++];
      if (op == '%' && (i >= src.length || '+-*/)'.contains(src[i]))) {
        v = v / 100;
        continue;
      }
      final r = _pow();
      v = op == '*' ? v * r : (op == '/' ? v / r : v % r);
    }
    return v;
  }

  double _pow() {
    final b = _unary();
    if (i < src.length && src[i] == '^') {
      i++;
      return math.pow(b, _pow()).toDouble();
    }
    return b;
  }

  double _unary() {
    if (i < src.length && src[i] == '-') {
      i++;
      return -_unary();
    }
    if (i < src.length && src[i] == '+') {
      i++;
      return _unary();
    }
    return _atom();
  }

  double _atom() {
    if (i < src.length && src[i] == '(') {
      i++;
      final v = _expr();
      if (i < src.length && src[i] == ')') i++;
      return v;
    }
    final start = i;
    while (i < src.length && ('0123456789.'.contains(src[i]))) {
      i++;
    }
    if (start == i) throw const FormatException('Number expected');
    return double.parse(src.substring(start, i));
  }
}

String calcFormat(double v) {
  if (v.isNaN || v.isInfinite) return 'Error';
  if (v == v.roundToDouble() && v.abs() < 1e15) return groupNum(v);
  final s = v.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

Widget _calc(WCtx c) {
  final m = app.store.map('calc');
  final hist = (m['hist'] as List? ?? []).map((e) => '$e').toList();
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [
        Icon(CupertinoIcons.plus_slash_minus, size: 16, color: c.dim),
        const Spacer(),
        if (c.lg) Text('History', style: c.t(13, dim: true)),
      ]),
      if (c.lg)
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.end, children: [
            for (final h in hist.take(5)) Padding(padding: const EdgeInsets.only(top: 4), child: Text(h, style: c.t(15, dim: true))),
          ]),
        )
      else
        const Spacer(),
      const SizedBox(height: 8),
      Text('${m['expr'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 14 : 18, dim: true)),
      fit(Text('${m['res'] ?? '0'}', style: c.t(c.sm ? 40 : (c.lg ? 72 : 52), w: FontWeight.w500)), a: Alignment.centerRight),
    ]),
  );
}

class _CalcPad extends StatefulWidget {
  const _CalcPad();

  @override
  State<_CalcPad> createState() => _CalcPadState();
}

class _CalcPadState extends State<_CalcPad> {
  late String expr = '';

  void _press(String k) {
    HapticFeedback.selectionClick();
    final m = app.store.map('calc');
    setState(() {
      switch (k) {
        case 'C':
          expr = '';
        case '⌫':
          if (expr.isNotEmpty) expr = expr.substring(0, expr.length - 1);
        case '=':
          try {
            final v = calcFormat(_Parser(expr).parse());
            final hist = (m['hist'] as List? ?? []).map((e) => '$e').toList();
            app.store.set('calc', {'expr': expr, 'res': v, 'hist': ['$expr = $v', ...hist].take(10).toList()});
            expr = v.replaceAll(' ', '');
          } catch (_) {
            app.store.set('calc', {...m, 'expr': expr, 'res': 'Error'});
          }
        default:
          expr += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['C', '(', ')', '÷', '7', '8', '9', '×', '4', '5', '6', '-', '1', '2', '3', '+', '%', '0', '.', '='];
    String preview = '';
    try {
      if (expr.isNotEmpty) preview = calcFormat(_Parser(expr).parse());
    } catch (_) {}
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: ShapeDecoration(color: K.card, shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(22))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              GestureDetector(onTap: () => _press('⌫'), child: const Icon(CupertinoIcons.delete_left, color: K.label2)),
              const Spacer(),
              Flexible(
                child: Text(expr.isEmpty ? '0' : expr,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: K.label, fontSize: 30, fontWeight: FontWeight.w300)),
              ),
            ]),
            Text(preview, style: const TextStyle(color: K.label2, fontSize: 18)),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final k in keys)
              GestureDetector(
                onTap: () => _press(k),
                child: Container(
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: k == '=' ? Colors.white : ('÷×-+'.contains(k) ? const Color(0xFF3A3A3C) : K.card),
                    shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(k, style: TextStyle(fontSize: 24, color: k == '=' ? Colors.black : Colors.white, fontWeight: FontWeight.w500)),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

// ───────────────────────── 50 Quick Translate ─────────────────────────

const _langs = {
  'auto': 'Detect',
  'en': 'English',
  'uz': 'Uzbek',
  'ru': 'Russian',
  'tr': 'Turkish',
  'ar': 'Arabic',
  'de': 'German',
  'fr': 'French',
  'es': 'Spanish',
  'ko': 'Korean',
  'ja': 'Japanese',
  'zh': 'Chinese',
};

String _lang(String code) => _langs[code.split('-').first.toLowerCase()] ?? code.toUpperCase();

Widget _translate(WCtx c) {
  final t = app.store.map('tr');
  final from = '${t['det'] ?? ''}'.isNotEmpty ? _lang('${t['det']}') : _lang('${t['from'] ?? 'auto'}');
  final to = _lang('${t['to'] ?? 'uz'}');
  final head = Row(children: [
    Text(from, style: c.t(c.sm ? 11 : 13, dim: true)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(CupertinoIcons.arrow_right, size: 12, color: c.dim)),
    Text(to, style: c.t(c.sm ? 11 : 13, c: c.pos, glow: false)),
  ]);
  if (c.md) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head,
        const Spacer(),
        Text('${t['src'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(15, dim: true)),
        const SizedBox(height: 4),
        Text('${t['out'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(26, h: 1.1)),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      head,
      SizedBox(height: c.lg ? 18 : 8),
      Text('${t['src'] ?? ''}', maxLines: c.lg ? 4 : 2, overflow: TextOverflow.ellipsis, style: c.t(c.lg ? 20 : 13, dim: true, h: 1.25)),
      if (c.lg) Divider(color: c.line, height: 30) else const Spacer(),
      Text('${t['out'] ?? ''}', maxLines: c.lg ? 6 : 3, overflow: TextOverflow.ellipsis, style: c.t(c.lg ? 30 : 18, h: 1.15)),
      if (c.lg) const Spacer(),
    ]),
  );
}

class _TranslateEditor extends StatefulWidget {
  const _TranslateEditor();

  @override
  State<_TranslateEditor> createState() => _TranslateEditorState();
}

class _TranslateEditorState extends State<_TranslateEditor> {
  late String text = '${app.store.map('tr')['src'] ?? ''}';
  bool busy = false;
  String? err;

  Future<void> _go() async {
    final t = app.store.map('tr');
    if (text.trim().isEmpty) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final r = await Api.translate(text.trim(), '${t['from'] ?? 'auto'}', '${t['to'] ?? 'uz'}');
      app.store.set('tr', {...t, 'src': text.trim(), 'out': r['out'], 'det': r['detected']});
    } catch (e) {
      setState(() => err = 'Translation failed. Check your connection.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final t = app.store.map('tr');
          void pick(String key, bool allowAuto) => showSheet(
                context,
                ListView(shrinkWrap: true, children: [
                  Section(children: [
                    for (final e in _langs.entries.where((e) => allowAuto || e.key != 'auto'))
                      RowItem(
                        title: e.value,
                        trailing: t[key] == e.key ? const Icon(CupertinoIcons.checkmark, color: K.blue, size: 18) : null,
                        onTap: () {
                          app.store.set('tr', {...t, key: e.key});
                          Navigator.pop(context);
                        },
                      ),
                  ]),
                ]),
              );
          return Column(children: [
            Section(children: [
              RowItem(title: 'From', value: _lang('${t['from'] ?? 'auto'}'), onTap: () => pick('from', true)),
              RowItem(title: 'To', value: _lang('${t['to'] ?? 'uz'}'), onTap: () => pick('to', false)),
            ]),
            Section(
              title: 'Text',
              footer: err ?? 'Translations by MyMemory.',
              children: [
                FieldRow(initial: text, placeholder: 'Type or paste text', maxLines: 5, onChanged: (v) => text = v),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: PillButton(busy ? 'Translating…' : 'Translate', icon: CupertinoIcons.globe, onTap: busy ? null : _go),
            ),
            if ('${t['out'] ?? ''}'.isNotEmpty)
              Section(title: 'Result', children: [
                RowItem(
                  title: '${t['out']}',
                  trailing: const Icon(CupertinoIcons.doc_on_doc, color: K.label2, size: 18),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '${t['out']}'));
                    toast(context, 'Copied');
                  },
                ),
              ]),
          ]);
        },
      );
}

// ───────────────────────── One-row glances ─────────────────────────

final creativeGlances = <String, Glance Function(WCtx)>{
  'news': (c) {
    final items = (app.hub.get<List>('news') ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Glance(items.isEmpty ? 'Top stories' : '${items.first['t']}', label: 'Hacker News', icon: CupertinoIcons.news_solid);
  },
  'space': (c) {
    final j = app.hub.get<Map<String, dynamic>>('iss');
    final sky = _nextSky();
    if (j == null) return Glance('ISS', label: sky.$1, icon: CupertinoIcons.rocket_fill);
    final lat = (j['latitude'] as num).toDouble(), lon = (j['longitude'] as num).toDouble();
    return Glance('${lat.abs().toStringAsFixed(1)}°${lat >= 0 ? 'N' : 'S'} ${lon.abs().toStringAsFixed(1)}°${lon >= 0 ? 'E' : 'W'}',
        label: 'ISS · ${groupNum((j['velocity'] as num? ?? 0).round())} km/h · ${sky.$1.split(' ').first}', icon: CupertinoIcons.rocket_fill, color: c.warm);
  },
  'earth': (c) {
    final qs = (app.hub.get<List>('quakes') ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) => (b['m'] as num).compareTo(a['m'] as num));
    if (qs.isEmpty) return const Glance('—', label: 'Loading earthquakes', icon: CupertinoIcons.waveform_path);
    return Glance('M${(qs.first['m'] as num).toStringAsFixed(1)}', label: '${qs.first['p']} · ${qs.length} today', icon: CupertinoIcons.waveform_path, color: c.warm);
  },
  'color': (c) {
    final p = palette();
    return Glance(hexOf(p[2]), label: p.map(hexOf).join('  '), icon: CupertinoIcons.circle_fill, color: p[2]);
  },
  'wallpaper': (c) {
    final n = DateTime.now();
    return Glance(kDays[n.weekday - 1], label: '${n.day} ${kMonths[n.month - 1]} · daily photo', icon: CupertinoIcons.photo_on_rectangle);
  },
  'word': (c) {
    final w = _todayWord();
    return Glance(w.$1, label: w.$3, icon: CupertinoIcons.textformat_abc);
  },
  'cards': (c) {
    final all = app.store.list('cards');
    final due = _due();
    if (all.isEmpty) return const Glance('—', label: 'Add flashcards', icon: CupertinoIcons.rectangle_stack_fill);
    return Glance('${(due.isNotEmpty ? due.first : all.first)['f']}', label: due.isEmpty ? 'All caught up' : '${due.length} cards due', icon: CupertinoIcons.rectangle_stack_fill);
  },
  'qr': (c) => Glance(_qrLabel(app.store.map('qr')), label: 'QR code · open the widget to scan', icon: CupertinoIcons.qrcode),
  'calc': (c) {
    final m = app.store.map('calc');
    return Glance('${m['res'] ?? '0'}', label: '${m['expr'] ?? ''}', icon: CupertinoIcons.plus_slash_minus);
  },
  'translate': (c) {
    final t = app.store.map('tr');
    return Glance('${t['out'] ?? ''}', label: '${t['src'] ?? ''}', icon: CupertinoIcons.globe);
  },
};
/// Merriam-Webster's Word of the Day; the built-in list is only an offline fallback.
(String, String, String, String) _todayWord() {
  final key = 'wotd:${dkey(DateTime.now())}';
  app.hub.ensure(key, const Duration(hours: 6), Api.wordOfDay);
  final j = app.hub.get<Map<String, dynamic>>(key);
  if (j != null && '${j['w']}'.isNotEmpty) {
    final w = '${j['w']}';
    return (w.isEmpty ? w : w[0].toUpperCase() + w.substring(1), '${j['pos']}', '${j['def']}', '${j['ex']}');
  }
  return _words[dayIndex(_words.length, 3)];
}