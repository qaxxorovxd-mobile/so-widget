import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import '../ui/location.dart';
import 'common.dart';

void seedEssential(Store s) {
  s.seed('chrono.battery', true);
  s.seed('chrono.seconds', false);
  final y = DateTime.now().year;
  s.seed('cal.marks', [
    {'d': '$y-12-31', 't': 'New Year’s Eve'},
    {'d': '${y + 1}-03-21', 't': 'Navruz'},
  ]);
  s.seed('countdown', [
    {'t': 'New Year', 'd': '${y + 1}-01-01', 'yearly': true},
    {'t': 'Navruz', 'd': '${y + 1}-03-21', 'yearly': true},
  ]);
  s.seed('world.cities', ['TAS', 'LON', 'NYC', 'TOK']);
}

final essentialWidgets = <WDef>[
  WDef(
    no: 1,
    id: 'chrono',
    name: 'Chrono',
    desc: 'Time, date, weekday and timezone in an editorial layout.',
    cat: WCat.essential,
    icon: CupertinoIcons.clock_fill,
    preferred: WSize.medium,
    face: _chrono,
    editor: (ctx) => const _ChronoEditor(),
  ),
  WDef(
    no: 2,
    id: 'power',
    name: 'Power',
    desc: 'Battery level, charging state and estimated time left.',
    cat: WCat.essential,
    icon: CupertinoIcons.bolt_fill,
    face: _power,
    editor: (ctx) => const _PowerEditor(),
  ),
  WDef(
    no: 3,
    id: 'atmosphere',
    name: 'Atmosphere',
    desc: 'Real-time weather told as a sentence: now, feels-like and rain.',
    cat: WCat.essential,
    icon: CupertinoIcons.cloud_sun_fill,
    face: _atmosphere,
    editor: (ctx) => _weatherEditor(),
  ),
  WDef(
    no: 4,
    id: 'forecast',
    name: 'Forecast',
    desc: 'Seven day forecast with temperature ranges.',
    cat: WCat.essential,
    icon: CupertinoIcons.calendar_today,
    preferred: WSize.large,
    face: _forecast,
    editor: (ctx) => _weatherEditor(),
  ),
  WDef(
    no: 5,
    id: 'calendar',
    name: 'Calendar',
    desc: 'Month at a glance with your important dates.',
    cat: WCat.essential,
    icon: CupertinoIcons.calendar,
    preferred: WSize.large,
    face: _calendar,
    editor: (ctx) => const _CalendarEditor(),
  ),
  WDef(
    no: 6,
    id: 'countdown',
    name: 'Countdown',
    desc: 'Days until birthdays, exams and events.',
    cat: WCat.essential,
    icon: CupertinoIcons.hourglass,
    face: _countdown,
    editor: (ctx) => const _CountdownEditor(),
  ),
  WDef(
    no: 7,
    id: 'world',
    name: 'World Clock',
    desc: 'Live analog clocks for the cities you care about.',
    cat: WCat.essential,
    icon: CupertinoIcons.globe,
    preferred: WSize.medium,
    face: _world,
    editor: (ctx) => const _WorldEditor(),
  ),
  WDef(
    no: 8,
    id: 'sun',
    name: 'Sun Cycle',
    desc: 'Sunrise, sunset and golden hour on a live arc.',
    cat: WCat.essential,
    icon: CupertinoIcons.sunset_fill,
    face: _sun,
    editor: (ctx) => _weatherEditor(),
  ),
  WDef(
    no: 9,
    id: 'moon',
    name: 'Moon Phase',
    desc: 'Current phase, illumination and the next full moon.',
    cat: WCat.essential,
    icon: CupertinoIcons.moon_fill,
    face: _moon,
  ),
  WDef(
    no: 10,
    id: 'air',
    name: 'Air Quality',
    desc: 'US AQI with PM2.5, PM10 and ozone.',
    cat: WCat.essential,
    icon: CupertinoIcons.wind,
    face: _air,
    editor: (ctx) => Column(children: [const LocationSection(showUnits: false), RefreshRow(_airKey)]),
  ),
];

Widget _weatherEditor() => Column(children: [const LocationSection(), RefreshRow(Wx.key)]);

// ───────────────────────── 01 Chrono ─────────────────────────

Widget _chrono(WCtx c) {
  if (app.store.flag('chrono.seconds') && c.live) {
    return ListenableBuilder(
      listenable: app.clock.second,
      builder: (context, _) => _chronoBody(c, DateTime.now(), true),
    );
  }
  return _chronoBody(c, DateTime.now(), false);
}

Widget _chronoBody(WCtx c, DateTime now, bool secs) {
  final h24 = app.settings.use24h;
  final time = hm(now, h24);
  final weekday = kDays[now.weekday - 1];
  final date = '${now.day} ${kMonths[now.month - 1].toUpperCase()}';
  final off = now.timeZoneOffset;
  final tz = 'GMT${off.isNegative ? '-' : '+'}${off.inHours.abs()}${off.inMinutes % 60 != 0 ? ':${two(off.inMinutes.abs() % 60)}' : ''}';
  final pill = app.store.flag('chrono.battery', true) && app.power.available ? BatteryPill(c, app.power.level, app.power.charging) : null;
  final ghost = c.fg.withValues(alpha: 0.92);
  final secText = secs ? Text(':${two(now.second)}', style: c.t(c.sm ? 18 : 26, dim: true)) : null;

  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [?pill, const Spacer(), Text(tz, style: c.t(11, dim: true))]),
            const Spacer(),
            fit(Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(time, style: c.t(52, w: FontWeight.w500)),
              ?secText,
            ])),
            fit(Text(weekday, style: c.script(30))),
            Text(date, style: c.t(11, dim: true, ls: 1.1)),
          ],
        ),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(weekday, style: c.t(14, dim: true)),
              const Spacer(),
              ?pill,
              if (pill == null) Text(tz, style: c.t(11, dim: true)),
            ]),
            const Spacer(),
            fit(Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(time, style: c.t(70, w: FontWeight.w400, h: 1)),
              ?secText,
            ])),
            const Spacer(),
            Text(date, style: c.t(11, dim: true, ls: 1.1)),
          ],
        ),
      );
    case WSize.large:
      return WShell(
        c: c,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [?pill, const Spacer(), Text('$tz · ${app.settings.city}', style: c.t(13, dim: true))]),
            Expanded(
              child: Center(
                child: fit(
                  Text(time, style: c.t(140, w: FontWeight.w400, c: ghost, glow: false, h: 1)),
                  a: Alignment.center,
                ),
              ),
            ),
            Text(weekday, style: c.script(58)),
            Row(children: [
              Text(date, style: c.t(16, dim: true, ls: 0.8)),
              const Spacer(),
              Text('${now.year} · W${_weekNo(now)}', style: c.t(14, dim: true)),
            ]),
          ],
        ),
      );
  }
}

int _weekNo(DateTime d) {
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstDay = DateTime(thursday.year, 1, 1);
  return (thursday.difference(firstDay).inDays / 7).floor() + 1;
}

class BatteryPill extends StatelessWidget {
  const BatteryPill(this.c, this.level, this.charging, {super.key});
  final WCtx c;
  final int level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final icon = charging
        ? CupertinoIcons.battery_charging
        : level > 80
            ? CupertinoIcons.battery_full
            : level > 40
                ? CupertinoIcons.battery_75_percent
                : level > 15
                    ? CupertinoIcons.battery_25_percent
                    : CupertinoIcons.battery_empty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: c.fg,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(9)),
        shadows: c.boxGlow(c.fg, 0.4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$level%', style: c.t(13, w: FontWeight.w700, c: c.bg, glow: false)),
        const SizedBox(width: 3),
        Icon(icon, size: 17, color: c.bg),
      ]),
    );
  }
}

class _ChronoEditor extends StatelessWidget {
  const _ChronoEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.store, app.settings]),
        builder: (context, _) => Section(title: 'Display', children: [
          SwitchRow('24-hour time', app.settings.use24h, (v) => app.settings.update(() => app.settings.use24h = v)),
          SwitchRow('Show seconds', app.store.flag('chrono.seconds'), (v) => app.store.set('chrono.seconds', v),
              subtitle: 'In-app only. Home screen snapshots update every minute.'),
          SwitchRow('Battery pill', app.store.flag('chrono.battery', true), (v) => app.store.set('chrono.battery', v)),
        ]),
      );
}

// ───────────────────────── 02 Power ─────────────────────────

Widget _power(WCtx c) {
  final p = app.power;
  if (!p.available) {
    return WEmpty(c, CupertinoIcons.battery_empty, 'Battery info is not available on this device.', title: 'Power');
  }
  final full = p.state == BatteryState.full || (p.charging && p.level >= 100);
  final left = p.minutesLeft;
  final leftStr = full
      ? 'Fully charged'
      : left == null
          ? ''
          : '${dur(Duration(minutes: left), short: true)} left';
  final head = WHeader(
    c,
    p.charging ? CupertinoIcons.bolt_fill : CupertinoIcons.battery_full,
    full ? 'Charged' : (p.charging ? 'Charging...' : 'On battery'),
    size: c.lg ? 22 : (c.sm ? 14 : 20),
  );
  final scale = Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text('0', style: c.mono(12)), Text('50', style: c.mono(12)), Text('100', style: c.mono(12))],
  );
  final v = p.level / 100;
  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          const SizedBox(height: 4),
          fit(Text('${p.level}%', style: c.t(40, w: FontWeight.w600))),
          Text(leftStr, maxLines: 1, style: c.t(13, dim: true)),
          const Spacer(),
          GlowBar(c, v, height: 40, tick: true),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          const SizedBox(height: 2),
          fit(Text('${p.level}% • $leftStr', style: c.t(26, w: FontWeight.w600))),
          const Spacer(),
          scale,
          const SizedBox(height: 6),
          GlowBar(c, v, height: 46, tick: true),
        ]),
      );
    case WSize.large:
      final hist = [...p.history.map((e) => e.toDouble()), p.level.toDouble()];
      return WShell(
        c: c,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          const SizedBox(height: 6),
          Text('${p.level}% • $leftStr', style: c.t(30, w: FontWeight.w600)),
          const SizedBox(height: 14),
          Expanded(
            child: hist.length > 2
                ? Spark(c, hist)
                : Center(child: Text('History builds up over time', style: c.t(13, dim: true))),
          ),
          const SizedBox(height: 18),
          scale,
          const SizedBox(height: 8),
          GlowBar(c, v, height: 74, tick: true),
        ]),
      );
  }
}

class _PowerEditor extends StatelessWidget {
  const _PowerEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.power,
        builder: (context, _) {
          final p = app.power;
          return Section(
            title: 'Battery',
            footer: 'Time left is estimated from how fast the level changes while the app is open.',
            children: [
              RowItem(title: 'Level', value: '${p.level}%'),
              RowItem(title: 'State', value: p.state.name),
              RowItem(title: 'Estimate', value: p.minutesLeft == null ? '—' : dur(Duration(minutes: p.minutesLeft!), short: true)),
            ],
          );
        },
      );
}

// ───────────────────────── 03 Atmosphere ─────────────────────────

Widget _atmosphere(WCtx c) {
  final w = Wx.now;
  if (w == null) return WEmpty(c, CupertinoIcons.cloud, 'Loading weather for ${app.settings.city}…', title: 'Atmosphere');
  final (cond, icon) = wmo(w.code, day: w.isDay);
  final (word, soon) = w.rainPhrase;
  final city = app.settings.city;

  InlineSpan b(String s, double fs) => TextSpan(text: s, style: c.t(fs, w: FontWeight.w600));
  InlineSpan d(String s, double fs) => TextSpan(text: s, style: c.t(fs, w: FontWeight.w600, dim: true));
  Widget flow(double fs) => Text.rich(
        TextSpan(children: [
          b('${w.temp}°', fs),
          d(' now\n', fs),
          d('in ', fs),
          b('$city\n', fs),
          d('feels ', fs),
          b('${w.feels}°\n', fs),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: fs * 0.25),
              child: Icon(wmo(word == 'rain' ? 61 : w.code, day: w.isDay).$2, size: fs * 0.95, color: c.fg, shadows: c.glowFor(c.fg)),
            ),
          ),
          b(word, fs),
          d(' ${soon.split(' ').first}\n', fs),
          d(soon.split(' ').skip(1).join(' '), fs),
        ]),
        style: c.t(fs, h: 1.12),
      );

  switch (c.size) {
    case WSize.small:
      return WShell(c: c, child: fit(flow(24), a: Alignment.topLeft));
    case WSize.medium:
      final tileText = c.fg;
      return WShell(
        c: c,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            flex: 11,
            child: Tile(
              c,
              color: c.faint,
              border: true,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 22, color: c.isLight ? c.fg : tileText),
                  const SizedBox(width: 6),
                  Expanded(child: Text(cond, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(15, c: c.isLight ? c.fg : tileText, glow: false))),
                ]),
                const Spacer(),
                fit(Text('${w.temp}°', style: c.t(58, w: FontWeight.w500, c: c.isLight ? c.fg : tileText, glow: false, h: 1))),
                const SizedBox(height: 4),
                Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(16, w: FontWeight.w500, c: c.isLight ? c.fg : tileText, glow: false)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 9,
            child: Column(children: [
              Expanded(
                child: Row(children: [
                  Expanded(child: _mini(c, 'Feels', '${w.feels}°')),
                  const SizedBox(width: 8),
                  Expanded(child: _mini(c, 'H/L', '${w.dMax.first}°/${w.dMin.first}°')),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Tile(
                  c,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(CupertinoIcons.drop_fill, size: 15, color: c.dim),
                    const SizedBox(width: 4),
                    Flexible(child: fit(Text('${w.humidity}%', style: c.t(16)))),
                    const Spacer(),
                    Icon(CupertinoIcons.wind, size: 15, color: c.dim),
                    const SizedBox(width: 4),
                    Flexible(flex: 3, child: fit(Text('${w.wind.round()} ${app.settings.metric ? 'km/h' : 'mph'}', style: c.t(16)))),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      );
    case WSize.large:
      final i0 = w.hourIndex;
      final hours = [for (var i = i0 + 1; i <= i0 + 5 && i < w.hTimes.length; i++) i];
      return WShell(
        c: c,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: fit(flow(40), a: Alignment.topLeft)),
          Divider(color: c.line, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final i in hours)
                Column(children: [
                  Text(hm(w.hTimes[i], app.settings.use24h).split(':').first + (app.settings.use24h ? '' : (w.hTimes[i].hour < 12 ? 'a' : 'p')), style: c.t(12, dim: true)),
                  const SizedBox(height: 6),
                  Icon(wmo(i < w.hRain.length && w.hRain[i] >= 50 ? 61 : w.code).$2, size: 18, color: c.fg),
                  const SizedBox(height: 6),
                  Text('${w.hTemp[i]}°', style: c.t(15)),
                ]),
            ],
          ),
        ]),
      );
  }
}

Widget _mini(WCtx c, String label, String value) => Tile(
      c,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: c.t(11, dim: true)),
        fit(Text(value, style: c.t(18))),
      ]),
    );

// ───────────────────────── 04 Forecast ─────────────────────────

Widget _forecast(WCtx c) {
  final w = Wx.now;
  if (w == null) return WEmpty(c, CupertinoIcons.calendar_today, 'Loading forecast…', title: 'Forecast');
  final days = w.dDays;
  final mx = w.dMax, mn = w.dMin, cd = w.dCode;
  final n = math.min(days.length, 7);
  String dn(int i) => i == 0 ? 'Today' : dayShort(days[i]);

  if (c.md) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.location_fill, app.settings.city, trailing: wmo(w.code).$1),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < n; i++)
              Column(children: [
                Text(i == 0 ? 'Now' : dayShort(days[i]), style: c.t(12, dim: true)),
                const SizedBox(height: 8),
                Icon(wmo(cd[i]).$2, size: 20, color: c.fg, shadows: c.glowFor(c.fg, 0.5)),
                const SizedBox(height: 8),
                Text('${mx[i]}°', style: c.t(16)),
                Text('${mn[i]}°', style: c.t(13, dim: true)),
              ]),
          ],
        ),
      ]),
    );
  }
  final lo = mn.take(n).reduce(math.min), hi = mx.take(n).reduce(math.max);
  final rows = c.sm ? 3 : n;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.sm ? 16 : 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.lg) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${w.temp}°', style: c.t(46, w: FontWeight.w600, h: 1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${wmo(w.code).$1}\n${app.settings.city}', maxLines: 2, style: c.t(14, dim: true, h: 1.25)),
          ),
        ]),
        Divider(color: c.line, height: 22),
      ] else
        WHeader(c, CupertinoIcons.calendar_today, 'Forecast'),
      for (var i = 0; i < rows; i++)
        Expanded(
          child: Row(children: [
            SizedBox(width: c.sm ? 40 : 56, child: Text(dn(i), maxLines: 1, style: c.t(c.sm ? 13 : 16))),
            Icon(wmo(cd[i]).$2, size: c.sm ? 16 : 20, color: c.fg),
            SizedBox(
              width: c.sm ? 30 : 40,
              child: Text('${mn[i]}°', textAlign: TextAlign.right, style: c.t(c.sm ? 13 : 16, dim: true)),
            ),
            if (c.lg) ...[
              const SizedBox(width: 10),
              Expanded(child: _range(c, (mn[i] - lo) / math.max(1, hi - lo), (mx[i] - lo) / math.max(1, hi - lo))),
              const SizedBox(width: 10),
            ] else
              const Spacer(),
            SizedBox(width: c.sm ? 30 : 36, child: Text('${mx[i]}°', textAlign: TextAlign.right, style: c.t(c.sm ? 13 : 16))),
          ]),
        ),
    ]),
  );
}

Widget _range(WCtx c, double a, double b) => LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth;
      return SizedBox(
        height: 6,
        child: Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: c.faint, borderRadius: BorderRadius.circular(3)))),
          Positioned(
            left: w * a,
            width: math.max(6, w * (b - a)),
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(colors: [c.fg.withValues(alpha: 0.55), c.warm]),
                boxShadow: c.boxGlow(c.warm, 0.3),
              ),
            ),
          ),
        ]),
      );
    });

// ───────────────────────── 05 Calendar ─────────────────────────

Map<String, String> _marks() => {
      for (final m in app.store.list('cal.marks')) (m['d'] ?? '').toString(): (m['t'] ?? '').toString(),
    };

Widget _monthGrid(WCtx c, DateTime now, double fs, Map<String, String> marks) {
  final first = DateTime(now.year, now.month, 1);
  final days = DateTime(now.year, now.month + 1, 0).day;
  final lead = first.weekday - 1;
  final cells = <DateTime?>[...List.filled(lead, null), for (var d = 1; d <= days; d++) DateTime(now.year, now.month, d)];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  final rows = cells.length ~/ 7;
  return Column(children: [
    Row(children: [
      for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
        Expanded(child: Center(child: Text(d, style: c.t(fs * 0.85, dim: true)))),
    ]),
    SizedBox(height: fs * 0.3),
    for (var r = 0; r < rows; r++)
      Expanded(
        child: Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final d = cells[r * 7 + i];
                if (d == null) return const SizedBox();
                final today = d.day == now.day;
                final marked = marks.containsKey(dkey(d));
                return Center(
                  child: Container(
                    width: fs * 2,
                    height: fs * 2,
                    alignment: Alignment.center,
                    decoration: today ? BoxDecoration(color: c.fg, shape: BoxShape.circle, boxShadow: c.boxGlow(c.fg, 0.6)) : null,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${d.day}',
                          style: c.t(fs,
                              w: today ? FontWeight.w700 : FontWeight.w500,
                              c: today ? c.bg : (i >= 5 ? c.dim : c.fg),
                              glow: false)),
                      if (marked)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(color: today ? c.bg : c.warm, shape: BoxShape.circle),
                        ),
                    ]),
                  ),
                );
              }),
            ),
        ]),
      ),
  ]);
}

(String, DateTime)? _nextMark() {
  final today = DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  (String, DateTime)? best;
  for (final e in _marks().entries) {
    final d = DateTime.tryParse(e.key);
    if (d == null || d.isBefore(t0)) continue;
    if (best == null || d.isBefore(best.$2)) best = (e.value, d);
  }
  return best;
}

Widget _calendar(WCtx c) {
  final now = DateTime.now();
  final marks = _marks();
  final next = _nextMark();
  final red = c.accent == c.fg ? const Color(0xFFFF453A) : c.accent;
  final nextText = next == null ? null : '${monShort(next.$2)} ${next.$2.day} · ${next.$1}';
  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kDays[now.weekday - 1].toUpperCase(), style: c.t(13, w: FontWeight.w700, c: red, ls: 0.6)),
          fit(Text('${now.day}', style: c.t(66, w: FontWeight.w500, h: 1))),
          Text('${kMonths[now.month - 1]} ${now.year}', style: c.t(13, dim: true)),
          const Spacer(),
          if (nextText != null) Text(nextText, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(12, h: 1.2)),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Row(children: [
          SizedBox(
            width: 110,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kDays[now.weekday - 1].toUpperCase(), style: c.t(12, w: FontWeight.w700, c: red, ls: 0.6)),
              fit(Text('${now.day}', style: c.t(58, w: FontWeight.w500, h: 1))),
              const Spacer(),
              if (nextText != null) Text(nextText, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(12, dim: true, h: 1.2)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(child: _monthGrid(c, now, 10, marks)),
        ]),
      );
    case WSize.large:
      return WShell(
        c: c,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(kMonths[now.month - 1], style: c.script(40, c: c.fg)),
            const SizedBox(width: 8),
            Text('${now.year}', style: c.t(18, dim: true)),
          ]),
          const SizedBox(height: 10),
          Expanded(child: _monthGrid(c, now, 14, marks)),
          if (nextText != null) ...[
            Divider(color: c.line, height: 16),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: c.warm, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(nextText, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(14))),
            ]),
          ],
        ]),
      );
  }
}

class _CalendarEditor extends StatelessWidget {
  const _CalendarEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final items = app.store.list('cal.marks')..sort((a, b) => '${a['d']}'.compareTo('${b['d']}'));
          return ListEditor(
            title: 'Important dates',
            items: items,
            titleOf: (m) => '${m['t']}',
            subtitleOf: (m) {
              final d = DateTime.tryParse('${m['d']}');
              return d == null ? '' : '${kDays[d.weekday - 1]}, ${d.day} ${kMonths[d.month - 1]} ${d.year}';
            },
            addLabel: 'Add date',
            footer: 'Swipe left to delete.',
            onAdd: () async {
              final d = await pickDateTime(context);
              if (d == null || !context.mounted) return;
              final t = await promptText(context, 'Label', placeholder: 'e.g. Exam');
              if (t == null || t.isEmpty) return;
              app.store.set('cal.marks', [...items, {'d': dkey(d), 't': t}]);
            },
            onDelete: (i) => app.store.set('cal.marks', [...items]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 06 Countdown ─────────────────────────

List<(String, DateTime)> _countdowns() {
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  final out = <(String, DateTime)>[];
  for (final m in app.store.list('countdown')) {
    var d = DateTime.tryParse('${m['d']}');
    if (d == null) continue;
    if (m['yearly'] == true) {
      while (d!.isBefore(t0)) {
        d = DateTime(d.year + 1, d.month, d.day);
      }
    }
    if (d.isBefore(t0)) continue;
    out.add(('${m['t']}', d));
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

Widget _countdown(WCtx c) {
  final items = _countdowns();
  if (items.isEmpty) return WEmpty(c, CupertinoIcons.hourglass, 'Add an event to count down to.', title: 'Countdown');
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  int days((String, DateTime) e) => e.$2.difference(t0).inDays;
  final main = items.first;
  final n = days(main);
  final unit = n == 1 ? 'day' : 'days';
  final big = n == 0 ? 'Today' : '$n';

  Widget others(int max, double fs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in items.skip(1).take(max))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: Text(e.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(fs, dim: true))),
                Text('${days(e)}d', style: c.t(fs)),
              ]),
            ),
        ],
      );

  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.hourglass, main.$1),
          const Spacer(),
          fit(Text(big, style: c.t(64, w: FontWeight.w600, h: 1))),
          Text(n == 0 ? 'It’s the day' : '$unit to go', style: c.t(14, dim: true)),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WHeader(c, CupertinoIcons.hourglass, 'Countdown'),
              const Spacer(),
              fit(Text(big, style: c.t(64, w: FontWeight.w600, h: 1))),
              Text(n == 0 ? main.$1 : '$unit until ${main.$1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(14, dim: true)),
            ]),
          ),
          if (items.length > 1) ...[
            Container(width: 1, color: c.line, margin: const EdgeInsets.symmetric(horizontal: 14)),
            SizedBox(width: 120, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [others(3, 13)])),
          ],
        ]),
      );
    case WSize.large:
      return WShell(
        c: c,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.hourglass, 'Countdown', size: 16),
          const Spacer(),
          fit(Text(big, style: c.t(110, w: FontWeight.w600, h: 1))),
          Text(n == 0 ? main.$1 : '$unit until', style: c.t(18, dim: true)),
          Text(main.$1, style: c.script(40)),
          Text('${kDays[main.$2.weekday - 1]}, ${main.$2.day} ${kMonths[main.$2.month - 1]}', style: c.t(14, dim: true)),
          const Spacer(),
          others(3, 15),
        ]),
      );
  }
}

class _CountdownEditor extends StatelessWidget {
  const _CountdownEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final items = app.store.list('countdown');
          return ListEditor(
            title: 'Events',
            items: items,
            titleOf: (m) => '${m['t']}',
            subtitleOf: (m) => '${m['d']}${m['yearly'] == true ? ' · repeats yearly' : ''}',
            addLabel: 'Add event',
            footer: 'Birthdays and holidays repeat yearly. Swipe left to delete.',
            onAdd: () async {
              final t = await promptText(context, 'Event name', placeholder: 'e.g. Birthday');
              if (t == null || t.isEmpty || !context.mounted) return;
              final d = await pickDateTime(context, initial: DateTime.now().add(const Duration(days: 7)));
              if (d == null || !context.mounted) return;
              final yearly = await confirm(context, 'Repeat yearly?', 'Useful for birthdays and anniversaries.', action: 'Repeat');
              app.store.set('countdown', [...items, {'t': t, 'd': dkey(d), 'yearly': yearly}]);
            },
            onDelete: (i) => app.store.set('countdown', [...items]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 07 World Clock ─────────────────────────

class City {
  const City(this.code, this.name, this.off, [this.dst = '']);
  final String code, name;
  final double off;
  final String dst;

  DateTime now() {
    final utc = DateTime.now().toUtc();
    var o = off;
    if (dst == 'eu' && _eu(utc)) o += 1;
    if (dst == 'us' && _us(utc)) o += 1;
    if (dst == 'au' && _au(utc)) o += 1;
    return utc.add(Duration(minutes: (o * 60).round()));
  }

  static DateTime _lastSun(int y, int m) {
    var d = DateTime.utc(y, m + 1, 0);
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  static DateTime _nthSun(int y, int m, int n) {
    var d = DateTime.utc(y, m, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (n - 1)));
  }

  bool _eu(DateTime u) {
    final a = _lastSun(u.year, 3).add(const Duration(hours: 1));
    final b = _lastSun(u.year, 10).add(const Duration(hours: 1));
    return !u.isBefore(a) && u.isBefore(b);
  }

  bool _us(DateTime u) {
    final a = _nthSun(u.year, 3, 2).add(Duration(hours: (2 - off).round()));
    final b = _nthSun(u.year, 11, 1).add(Duration(hours: (1 - off).round()));
    return !u.isBefore(a) && u.isBefore(b);
  }

  bool _au(DateTime u) {
    final end = _nthSun(u.year, 4, 1).subtract(const Duration(hours: 16));
    final start = _nthSun(u.year, 10, 1).subtract(const Duration(hours: 16));
    return u.isBefore(end) || !u.isBefore(start);
  }
}

const kCities = [
  City('TAS', 'Tashkent', 5),
  City('SKD', 'Samarkand', 5),
  City('ALA', 'Almaty', 5),
  City('DXB', 'Dubai', 4),
  City('BAK', 'Baku', 4),
  City('MOW', 'Moscow', 3),
  City('IST', 'Istanbul', 3),
  City('RUH', 'Riyadh', 3),
  City('MEC', 'Mecca', 3),
  City('CAI', 'Cairo', 2),
  City('BER', 'Berlin', 1, 'eu'),
  City('PAR', 'Paris', 1, 'eu'),
  City('LON', 'London', 0, 'eu'),
  City('NYC', 'New York', -5, 'us'),
  City('CHI', 'Chicago', -6, 'us'),
  City('SFO', 'San Francisco', -8, 'us'),
  City('BOG', 'Bogotá', -5),
  City('SAO', 'São Paulo', -3),
  City('DEL', 'New Delhi', 5.5),
  City('BJS', 'Beijing', 8),
  City('SIN', 'Singapore', 8),
  City('SEL', 'Seoul', 9),
  City('TOK', 'Tokyo', 9),
  City('SYD', 'Sydney', 10, 'au'),
];

List<City> _myCities() {
  final codes = app.store.strs('world.cities');
  return [for (final code in codes) ...kCities.where((c) => c.code == code)];
}

String _diff(City city) {
  final local = DateTime.now();
  final there = city.now();
  final h = (there.difference(DateTime.utc(local.year, local.month, local.day, local.hour, local.minute)).inMinutes / 60).round();
  if (h == 0) return 'Local';
  return '${h > 0 ? '+' : ''}${h}h';
}

Widget _world(WCtx c) {
  final cities = _myCities();
  if (cities.isEmpty) return WEmpty(c, CupertinoIcons.globe, 'Add cities to compare time.', title: 'World Clock');
  final h24 = app.settings.use24h;
  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(children: [
          for (final city in cities.take(3))
            Expanded(
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(city.code, style: c.t(13, w: FontWeight.w700)),
                  Text(_diff(city), style: c.t(11, dim: true)),
                ]),
                const Spacer(),
                Text(hm(city.now(), h24), style: c.t(26, w: FontWeight.w500)),
              ]),
            ),
        ]),
      );
    case WSize.medium:
      final list = cities.take(4).toList();
      return WShell(
        c: c,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final city in list)
              SizedBox(
                width: (c.dims.width - 28 - (list.length - 1) * 10) / list.length,
                child: Column(children: [
                  Dial(c, city.now(), label: city.code),
                  const Spacer(),
                  Text(hm(city.now(), h24), style: c.t(15)),
                  Text(_diff(city), style: c.t(11, dim: true)),
                ]),
              ),
          ],
        ),
      );
    case WSize.large:
      final list = cities.take(4).toList();
      return WShell(
        c: c,
        padding: const EdgeInsets.all(14),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.98,
          children: [
            for (final city in list)
              Tile(
                c,
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Center(child: Dial(c, city.now(), label: city.code))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(city.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(13, dim: true))),
                    Text(hm(city.now(), h24), style: c.t(15)),
                  ]),
                ]),
              ),
          ],
        ),
      );
  }
}

class _WorldEditor extends StatelessWidget {
  const _WorldEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final codes = app.store.strs('world.cities');
          final items = [for (final code in codes) {'c': code}];
          String nameOf(String code) => kCities.firstWhere((e) => e.code == code, orElse: () => const City('', '?', 0)).name;
          return ListEditor(
            title: 'Cities',
            items: items,
            titleOf: (m) => nameOf('${m['c']}'),
            subtitleOf: (m) => '${m['c']}',
            addLabel: 'Add city',
            footer: 'The first four cities are shown. Daylight saving is applied for Europe, US and Sydney.',
            onAdd: () => showSheet(
              context,
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView(children: [
                  Section(children: [
                    for (final city in kCities.where((e) => !codes.contains(e.code)))
                      RowItem(
                        title: city.name,
                        value: hm(city.now(), app.settings.use24h),
                        onTap: () {
                          app.store.set('world.cities', [...codes, city.code]);
                          Navigator.pop(context);
                        },
                      ),
                  ]),
                ]),
              ),
              title: 'Add city',
            ),
            onDelete: (i) => app.store.set('world.cities', [...codes]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 08 Sun Cycle ─────────────────────────

Widget _sun(WCtx c) {
  final w = Wx.now;
  if (w == null || w.sunrise.isEmpty) return WEmpty(c, CupertinoIcons.sunrise_fill, 'Loading sun times…', title: 'Sun Cycle');
  final now = w.localNow;
  final rise = w.sunrise[0], set = w.sunset[0];
  final riseNext = w.sunrise.length > 1 ? w.sunrise[1] : rise.add(const Duration(days: 1));
  final h24 = app.settings.use24h;
  final golden = set.subtract(const Duration(hours: 1));
  final (label, at, icon) = now.isBefore(rise)
      ? ('Sunrise', rise, CupertinoIcons.sunrise_fill)
      : now.isBefore(set)
          ? ('Sunset', set, CupertinoIcons.sunset_fill)
          : ('Sunrise', riseNext, CupertinoIcons.sunrise_fill);
  final until = at.difference(now);
  final daylight = set.difference(rise);
  final f = (now.difference(rise).inSeconds / math.max(1, daylight.inSeconds)).clamp(-0.08, 1.08).toDouble();

  Widget arc() => CustomPaint(
        size: Size.infinite,
        painter: _SunArc(f, c.fg, c.warm, c.s.glow ? c.s.glowStrength : 0),
      );

  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Spacer(),
          Icon(icon, size: 44, color: c.warm, shadows: c.glowFor(c.warm, 1.2)),
          const SizedBox(height: 6),
          fit(Text(hm(at, h24), style: c.t(36, w: FontWeight.w500)), a: Alignment.center),
          Text('$label in ${dur(until, short: true)}', style: c.t(12, dim: true)),
          const Spacer(),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Row(children: [
          Expanded(
            flex: 6,
            child: Column(children: [
              Expanded(child: arc()),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(hm(rise, h24), style: c.t(13, dim: true)),
                Text(hm(set, h24), style: c.t(13, dim: true)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: c.t(13, dim: true)),
              fit(Text(hm(at, h24), style: c.t(34, w: FontWeight.w500))),
              const SizedBox(height: 8),
              Text('Golden hour', style: c.t(12, dim: true)),
              Text('${hm(golden, h24)} – ${hm(set, h24)}', style: c.t(15, c: c.warm)),
            ]),
          ),
        ]),
      );
    case WSize.large:
      return WShell(
        c: c,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.location_fill, app.settings.city, trailing: 'in ${dur(until, short: true)}'),
          const SizedBox(height: 8),
          Expanded(child: arc()),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _mini(c, 'Sunrise', hm(rise, h24))),
            const SizedBox(width: 8),
            Expanded(child: _mini(c, 'Sunset', hm(set, h24))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _mini(c, 'Golden hour', hm(golden, h24))),
            const SizedBox(width: 8),
            Expanded(child: _mini(c, 'Daylight', dur(daylight, short: true))),
          ]),
        ]),
      );
  }
}

class _SunArc extends CustomPainter {
  _SunArc(this.f, this.fg, this.sun, this.glow);
  final double f, glow;
  final Color fg, sun;

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height * 0.82;
    final rect = Rect.fromLTRB(4, size.height * 0.08, size.width - 4, base * 2 - size.height * 0.08);
    canvas.drawLine(Offset(0, base), Offset(size.width, base), Paint()
      ..color = fg.withValues(alpha: 0.25)
      ..strokeWidth = 1);
    final path = Path()..addArc(rect, math.pi, math.pi);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = fg.withValues(alpha: 0.3);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 3.5), dash);
      }
      final p = f.clamp(0.0, 1.0);
      canvas.drawPath(
        m.extractPath(0, m.length * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = sun,
      );
    }
    final a = math.pi + math.pi * f;
    final o = Offset(rect.center.dx + rect.width / 2 * math.cos(a), rect.center.dy + rect.height / 2 * math.sin(a));
    final up = f >= 0 && f <= 1;
    if (glow > 0 && up) {
      canvas.drawCircle(o, 16, Paint()
        ..color = sun.withValues(alpha: 0.5 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 8 * glow));
    }
    canvas.drawCircle(o, 7, Paint()..color = up ? sun : fg.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(covariant _SunArc o) => o.f != f || o.sun != sun;
}

// ───────────────────────── 09 Moon ─────────────────────────

class MoonDisc extends StatelessWidget {
  const MoonDisc(this.c, this.phase, {super.key});
  final WCtx c;
  final double phase;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _MoonPainter(phase, c.fg, c.faint, c.s.glow ? c.s.glowStrength : 0)),
      );
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.p, this.lit, this.dark, this.glow);
  final double p, glow;
  final Color lit, dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.86;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..color = dark);
    final k = math.cos(2 * math.pi * p);
    final right = p < 0.5;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..arcTo(rect, -math.pi / 2, right ? math.pi : -math.pi, false);
    final ell = Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r);
    if (k > 0) {
      path.arcTo(ell, math.pi / 2, right ? -math.pi : math.pi, false);
    } else {
      path.arcTo(ell, math.pi / 2, right ? math.pi : -math.pi, false);
    }
    path.close();
    if (glow > 0) {
      canvas.drawPath(path, Paint()
        ..color = lit.withValues(alpha: 0.5 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 14 * glow));
    }
    canvas.drawPath(path, Paint()..color = lit);
    // subtle craters
    final crater = Paint()..color = Colors.black.withValues(alpha: 0.07);
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.2), r * 0.18, crater);
    canvas.drawCircle(c + Offset(r * 0.25, r * 0.3), r * 0.12, crater);
    canvas.drawCircle(c + Offset(r * 0.35, -r * 0.35), r * 0.08, crater);
  }

  @override
  bool shouldRepaint(covariant _MoonPainter o) => o.p != p || o.lit != lit;
}

Widget _moon(WCtx c) {
  final now = DateTime.now();
  final p = Moon.phase(now);
  final illum = (Moon.illumination(now) * 100).round();
  final full = Moon.next(now, 0.5);
  final newM = Moon.next(now, 0.0);
  final toFull = full.difference(now).inDays;
  final name = Moon.name(p);
  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Center(child: MoonDisc(c, p))),
          const SizedBox(height: 6),
          fit(Text(name, style: c.t(16))),
          Text('$illum% · full in ${toFull}d', style: c.t(12, dim: true)),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Row(children: [
          MoonDisc(c, p),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              fit(Text(name, style: c.script(34))),
              Text('$illum% illuminated', style: c.t(15)),
              const SizedBox(height: 8),
              Text('Full moon · ${full.day} ${monShort(full)}', style: c.t(13, dim: true)),
              Text('New moon · ${newM.day} ${monShort(newM)}', style: c.t(13, dim: true)),
            ]),
          ),
        ]),
      );
    case WSize.large:
      final phases = [(0.0, 'New'), (0.25, 'First Q'), (0.5, 'Full'), (0.75, 'Last Q')]
          .map((e) => (e.$1, e.$2, Moon.next(now, e.$1)))
          .toList()
        ..sort((a, b) => a.$3.compareTo(b.$3));
      return WShell(
        c: c,
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Expanded(child: MoonDisc(c, p)),
          const SizedBox(height: 10),
          Text(name, style: c.script(42)),
          Text('$illum% illuminated · ${Moon.age(now).toStringAsFixed(1)} days old', style: c.t(14, dim: true)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final ph in phases)
                Column(children: [
                  SizedBox(width: 30, height: 30, child: MoonDisc(c.copyGlow(false), ph.$1)),
                  const SizedBox(height: 4),
                  Text(ph.$2, style: c.t(11, dim: true)),
                  Text('${ph.$3.day} ${monShort(ph.$3)}', style: c.t(13)),
                ]),
            ],
          ),
        ]),
      );
  }
}

extension on WCtx {
  WCtx copyGlow(bool g) => WCtx(s.copyWith(glow: g), size, live: live);
}

// ───────────────────────── 10 Air Quality ─────────────────────────

String get _airKey => 'air:${app.settings.lat.toStringAsFixed(2)},${app.settings.lon.toStringAsFixed(2)}';

(String, Color) aqiInfo(int v) {
  if (v <= 50) return ('Good', const Color(0xFF30D158));
  if (v <= 100) return ('Moderate', const Color(0xFFFFD60A));
  if (v <= 150) return ('Sensitive', const Color(0xFFFF9F0A));
  if (v <= 200) return ('Unhealthy', const Color(0xFFFF453A));
  if (v <= 300) return ('Very unhealthy', const Color(0xFFBF5AF2));
  return ('Hazardous', const Color(0xFF8E1B3A));
}

Widget _air(WCtx c) {
  final s = app.settings;
  app.hub.ensure(_airKey, const Duration(minutes: 15), () => Api.air(s.lat, s.lon));
  final j = app.hub.get<Map<String, dynamic>>(_airKey);
  if (j == null) return WEmpty(c, CupertinoIcons.wind, 'Loading air quality…', title: 'Air Quality');
  final cur = Map<String, dynamic>.from(j['current'] as Map);
  final aqi = (cur['us_aqi'] as num? ?? 0).round();
  final (label, col) = aqiInfo(aqi);
  String v(String k) => (cur[k] as num?)?.round().toString() ?? '—';

  Widget scale(double h) => LayoutBuilder(builder: (context, bc) {
        final x = (aqi / 300).clamp(0.0, 1.0) * bc.maxWidth;
        return SizedBox(
          height: h + 6,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h),
                  gradient: const LinearGradient(colors: [
                    Color(0xFF30D158),
                    Color(0xFFFFD60A),
                    Color(0xFFFF9F0A),
                    Color(0xFFFF453A),
                    Color(0xFFBF5AF2),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: x - (h + 6) / 2,
              top: 0,
              width: h + 6,
              height: h + 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.fg,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 2),
                  boxShadow: c.boxGlow(col, 0.8),
                ),
              ),
            ),
          ]),
        );
      });

  Widget pm(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: c.t(11, dim: true)),
        Text(v, style: c.t(17)),
      ]);

  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.wind, 'AQI'),
          const Spacer(),
          fit(Text('$aqi', style: c.t(52, w: FontWeight.w600, h: 1))),
          Text(label, style: c.t(14, c: col)),
          const SizedBox(height: 10),
          scale(6),
        ]),
      );
    case WSize.medium:
    case WSize.large:
      final lg = c.lg;
      return WShell(
        c: c,
        padding: EdgeInsets.all(lg ? 22 : 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.wind, 'Air Quality · ${app.settings.city}'),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$aqi', style: c.t(lg ? 80 : 50, w: FontWeight.w600, h: 1)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(lg ? 22 : 17, c: col)),
              ),
            ),
            if (!lg) ...[pm('PM2.5', v('pm2_5')), const SizedBox(width: 14), pm('PM10', v('pm10')), const SizedBox(width: 14), pm('O₃', v('ozone'))],
          ]),
          SizedBox(height: lg ? 18 : 12),
          scale(lg ? 8 : 6),
          if (lg) ...[
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              pm('PM2.5 µg/m³', v('pm2_5')),
              pm('PM10 µg/m³', v('pm10')),
              pm('O₃ µg/m³', v('ozone')),
              pm('NO₂ µg/m³', v('nitrogen_dioxide')),
            ]),
            const Spacer(),
            Text(
              aqi <= 50
                  ? 'Great day to be outside.'
                  : aqi <= 100
                      ? 'Acceptable. Sensitive people should take it easy.'
                      : 'Consider limiting time outdoors.',
              style: c.t(15, dim: true, h: 1.3),
            ),
          ],
        ]),
      );
  }
}

// ───────────────────────── One-row glances ─────────────────────────

final essentialGlances = <String, Glance Function(WCtx)>{
  'chrono': (c) {
    final n = DateTime.now();
    return Glance(hm(n, app.settings.use24h),
        label: '${kDays[n.weekday - 1]}, ${n.day} ${kMonths[n.month - 1]}', icon: CupertinoIcons.clock_fill,
        trailing: app.power.available ? '${app.power.level}%' : null);
  },
  'power': (c) {
    final p = app.power;
    final l = p.minutesLeft;
    final left = l == null ? '' : ' · ${dur(Duration(minutes: l), short: true)} left';
    return Glance('${p.level}%',
        label: (p.charging ? 'Charging' : 'On battery') + left,
        icon: p.charging ? CupertinoIcons.bolt_fill : CupertinoIcons.battery_full,
        progress: p.level / 100);
  },
  'atmosphere': (c) {
    final w = Wx.now;
    if (w == null) return const Glance('—', label: 'Loading weather', icon: CupertinoIcons.cloud);
    final (cond, icon) = wmo(w.code, day: w.isDay);
    final (word, soon) = w.rainPhrase;
    return Glance('${w.temp}°', label: '$cond · feels ${w.feels}° · $word $soon', icon: icon, trailing: app.settings.city);
  },
  'forecast': (c) {
    final w = Wx.now;
    if (w == null || w.dMax.length < 2) return const Glance('—', label: 'Loading forecast', icon: CupertinoIcons.calendar_today);
    return Glance('${w.dMax.first}° / ${w.dMin.first}°',
        label: 'Tomorrow ${w.dMax[1]}° · ${wmo(w.dCode[1]).$1}', icon: wmo(w.dCode.first).$2);
  },
  'calendar': (c) {
    final n = DateTime.now();
    final next = _nextMark();
    return Glance('${kDays[n.weekday - 1]} ${n.day}',
        label: next == null ? '${kMonths[n.month - 1]} ${n.year}' : '${next.$1} · ${monShort(next.$2)} ${next.$2.day}',
        icon: CupertinoIcons.calendar);
  },
  'countdown': (c) {
    final items = _countdowns();
    if (items.isEmpty) return const Glance('—', label: 'Add an event', icon: CupertinoIcons.hourglass);
    final n = DateTime.now();
    final d = items.first.$2.difference(DateTime(n.year, n.month, n.day)).inDays;
    return Glance(d == 0 ? 'Today' : '$d ${d == 1 ? 'day' : 'days'}', label: items.first.$1, icon: CupertinoIcons.hourglass);
  },
  'world': (c) {
    final cs = _myCities();
    final h24 = app.settings.use24h;
    if (cs.isEmpty) return const Glance('—', label: 'Add cities', icon: CupertinoIcons.globe);
    return Glance('${cs.first.code} ${hm(cs.first.now(), h24)}',
        label: cs.skip(1).take(3).map((x) => '${x.code} ${hm(x.now(), h24)}').join('  ·  '), icon: CupertinoIcons.globe);
  },
  'sun': (c) {
    final w = Wx.now;
    if (w == null || w.sunrise.isEmpty) return const Glance('—', label: 'Loading sun times', icon: CupertinoIcons.sunrise_fill);
    final now = w.localNow;
    final rise = w.sunrise[0], set = w.sunset[0];
    final (label, at) = now.isBefore(rise)
        ? ('Sunrise', rise)
        : now.isBefore(set)
            ? ('Sunset', set)
            : ('Sunrise', w.sunrise.length > 1 ? w.sunrise[1] : rise.add(const Duration(days: 1)));
    return Glance(hm(at, app.settings.use24h),
        label: '$label in ${dur(at.difference(now), short: true)}',
        icon: label == 'Sunset' ? CupertinoIcons.sunset_fill : CupertinoIcons.sunrise_fill,
        color: c.warm);
  },
  'moon': (c) {
    final n = DateTime.now();
    final full = Moon.next(n, 0.5);
    return Glance(Moon.name(Moon.phase(n)),
        label: '${(Moon.illumination(n) * 100).round()}% · full moon ${full.day} ${monShort(full)}', icon: CupertinoIcons.moon_fill);
  },
  'air': (c) {
    final j = app.hub.get<Map<String, dynamic>>(_airKey);
    if (j == null) return const Glance('—', label: 'Loading air quality', icon: CupertinoIcons.wind);
    final cur = Map<String, dynamic>.from(j['current'] as Map);
    final aqi = (cur['us_aqi'] as num? ?? 0).round();
    final (label, col) = aqiInfo(aqi);
    return Glance('AQI $aqi', label: '$label · PM2.5 ${(cur['pm2_5'] as num?)?.round() ?? '—'}',
        icon: CupertinoIcons.wind, color: col, progress: aqi / 300);
  },
};