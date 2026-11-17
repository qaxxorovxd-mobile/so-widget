import 'dart:io';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import '../ui/location.dart';

void seedDigital(Store s) {
  s.seed('servers', [
    {'n': 'qaxxorov.uz', 'u': 'https://qaxxorov.uz'},
    {'n': 'GitHub API', 'u': 'https://api.github.com'},
  ]);
  s.seed('crypto.ids', ['bitcoin', 'ethereum', 'solana', 'the-open-network', 'binancecoin']);
  s.seed('fx.base', 'USD');
  s.seed('fx.pairs', ['UZS', 'EUR', 'RUB', 'KZT', 'GBP']);
  s.seed('stocks', ['AAPL', 'NVDA', 'TSLA', 'MSFT', 'GOOGL']);
  s.seed('parcels', [
    {'n': 'Mechanical keyboard', 'code': 'UZ123456789', 'stage': 2},
  ]);
  s.seed('sites', ['qaxxorov.uz', 'github.com', 'google.com']);
  s.seed('repos', ['flutter/flutter', 'dart-lang/sdk', 'microsoft/vscode', 'vercel/next.js', 'denoland/deno']);
}

final _started = DateTime.now();

final digitalWidgets = <WDef>[
  WDef(
    no: 21,
    id: 'pulse',
    name: 'System Pulse',
    desc: 'Memory, cores, battery and network health at a glance.',
    cat: WCat.digital,
    icon: CupertinoIcons.waveform_path_ecg,
    face: _pulse,
    editor: (ctx) => const _PulseEditor(),
  ),
  WDef(
    no: 22,
    id: 'network',
    name: 'Network',
    desc: 'Download speed, ping and connection status.',
    cat: WCat.digital,
    icon: CupertinoIcons.wifi,
    face: _network,
    editor: (ctx) => const RefreshRow('net', label: 'Run speed test'),
  ),
  WDef(
    no: 23,
    id: 'github',
    name: 'GitHub Pulse',
    desc: 'Contribution graph and activity for any GitHub user.',
    cat: WCat.digital,
    icon: CupertinoIcons.chevron_left_slash_chevron_right,
    preferred: WSize.medium,
    face: _github,
    editor: (ctx) => const _GithubEditor(),
  ),
  WDef(
    no: 24,
    id: 'server',
    name: 'Server Status',
    desc: 'VPS and API health: status, latency and optional metrics.',
    cat: WCat.digital,
    icon: CupertinoIcons.cloud_upload_fill,
    face: _server,
    editor: (ctx) => const _UrlListEditor(storeKey: 'servers', hubKey: 'servers', title: 'Endpoints', withName: true,
        footer: 'If an endpoint returns JSON with cpu, ram, disk or uptime fields, they are shown too.'),
  ),
  WDef(
    no: 25,
    id: 'crypto',
    name: 'Crypto Market',
    desc: 'BTC, ETH and more with 7-day sparklines.',
    cat: WCat.digital,
    icon: CupertinoIcons.bitcoin_circle_fill,
    face: _crypto,
    editor: (ctx) => const _SymbolsEditor(storeKey: 'crypto.ids', hubPrefix: 'crypto', title: 'Coins',
        hint: 'CoinGecko id, e.g. dogecoin', footer: 'Use CoinGecko coin ids (bitcoin, ethereum, solana…).'),
  ),
  WDef(
    no: 26,
    id: 'currency',
    name: 'Currency',
    desc: 'Exchange rates for USD, EUR, UZS and more.',
    cat: WCat.digital,
    icon: CupertinoIcons.money_dollar_circle_fill,
    face: _currency,
    editor: (ctx) => const _CurrencyEditor(),
  ),
  WDef(
    no: 27,
    id: 'stocks',
    name: 'Stock Watch',
    desc: 'US stock prices and daily change.',
    cat: WCat.digital,
    icon: CupertinoIcons.graph_square_fill,
    face: _stocks,
    editor: (ctx) => const _SymbolsEditor(storeKey: 'stocks', hubPrefix: 'stocks', title: 'Tickers',
        hint: 'Ticker, e.g. AMZN', upper: true, footer: 'US-listed tickers. Data via Stooq, may be delayed.'),
  ),
  WDef(
    no: 28,
    id: 'parcels',
    name: 'Package Tracker',
    desc: 'Track orders and parcels through each stage.',
    cat: WCat.digital,
    icon: CupertinoIcons.cube_box_fill,
    face: _parcels,
    editor: (ctx) => const _ParcelEditor(),
  ),
  WDef(
    no: 29,
    id: 'sites',
    name: 'Website Monitor',
    desc: 'Uptime, latency and SSL certificate expiry.',
    cat: WCat.digital,
    icon: CupertinoIcons.lock_shield_fill,
    face: _sites,
    editor: (ctx) => const _UrlListEditor(storeKey: 'sites', hubKey: 'sites', title: 'Websites', withName: false,
        footer: 'Checked every 10 minutes while the app is open.'),
  ),
  WDef(
    no: 30,
    id: 'devfeed',
    name: 'Dev Feed',
    desc: 'Latest releases from the repos you follow.',
    cat: WCat.digital,
    icon: CupertinoIcons.tag_fill,
    face: _devfeed,
    editor: (ctx) => const _SymbolsEditor(storeKey: 'repos', hubPrefix: 'repos', title: 'Repositories',
        hint: 'owner/repo', footer: 'GitHub repositories as owner/repo.'),
  ),
];

Widget _loading(WCtx c, IconData i, String title, String key) =>
    WEmpty(c, i, app.hub.error(key) != null ? 'Couldn’t load. ${app.hub.error(key)}' : 'Loading…', title: title);

Color _chg(WCtx c, num v) => v >= 0 ? c.pos : c.neg;

// ───────────────────────── 21 System Pulse ─────────────────────────

Widget _pulse(WCtx c) {
  final rss = ProcessInfo.currentRss / 1024 / 1024;
  final cores = Platform.numberOfProcessors;
  final net = app.hub.get<Map<String, dynamic>>('net');
  final ping = (net?['ping'] as num?)?.toInt();
  final bat = app.power.available ? app.power.level / 100 : 0.0;
  final memV = (rss / 512).clamp(0.0, 1.0);
  final pingV = ping == null ? 0.0 : (1 - (ping / 400)).clamp(0.05, 1.0);
  final up = DateTime.now().difference(_started);
  final cols = [c.fg, c.pos, c.warm];
  Widget stat(String k, String v, Color dot) => Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(k, style: c.t(13, dim: true))),
        Text(v, style: c.t(14)),
      ]);
  final rings = Rings(c, [memV, bat, pingV], colors: cols, stroke: c.sm ? 9 : 11, gap: 3);
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(children: [
        Expanded(child: rings),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${rss.round()}MB', style: c.t(12)),
          Text('${(bat * 100).round()}%', style: c.t(12, c: c.pos)),
          Text(ping == null ? '—' : '${ping}ms', style: c.t(12, c: c.warm)),
        ]),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: c.md
        ? Row(children: [
            rings,
            const SizedBox(width: 18),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                stat('App memory', '${rss.round()} MB', cols[0]),
                stat('Battery', app.power.available ? '${app.power.level}%' : '—', cols[1]),
                stat('Latency', ping == null ? '—' : '$ping ms', cols[2]),
                stat('Cores', '$cores', c.line),
              ]),
            ),
          ])
        : Column(children: [
            WHeader(c, CupertinoIcons.waveform_path_ecg, 'System Pulse', trailing: Platform.operatingSystem),
            const SizedBox(height: 14),
            Expanded(child: rings),
            const SizedBox(height: 16),
            stat('App memory', '${rss.round()} MB', cols[0]),
            const SizedBox(height: 6),
            stat('Battery', app.power.available ? '${app.power.level}%' : '—', cols[1]),
            const SizedBox(height: 6),
            stat('Latency', ping == null ? '—' : '$ping ms', cols[2]),
            const SizedBox(height: 6),
            stat('CPU cores · uptime', '$cores · ${dur(up, short: true)}', c.line),
          ]),
  );
}

class _PulseEditor extends StatelessWidget {
  const _PulseEditor();

  @override
  Widget build(BuildContext context) => Column(children: [
        Section(
          title: 'Device',
          footer: 'Mobile systems don’t let apps read total CPU and RAM usage, so System Pulse shows what is measurable: '
              'this app’s memory, CPU cores, battery and network latency.',
          children: [
            RowItem(title: 'Platform', value: Platform.operatingSystem),
            RowItem(title: 'Version', subtitle: Platform.operatingSystemVersion),
            RowItem(title: 'CPU cores', value: '${Platform.numberOfProcessors}'),
          ],
        ),
        const RefreshRow('net', label: 'Measure latency'),
      ]);
}

// ───────────────────────── 22 Network ─────────────────────────

Widget _network(WCtx c) {
  app.hub.ensure('net', const Duration(minutes: 5), Api.speed);
  final net = app.hub.get<Map<String, dynamic>>('net');
  final err = app.hub.error('net');
  final online = err == null && net != null;
  final busy = app.hub.busy('net');
  if (net == null) {
    return WEmpty(c, CupertinoIcons.wifi, busy ? 'Testing your connection…' : (err ?? 'Waiting…'), title: 'Network');
  }
  final mbps = (net['mbps'] as num? ?? 0).toDouble();
  final ping = (net['ping'] as num? ?? 0).toInt();
  final at = DateTime.fromMillisecondsSinceEpoch((net['at'] as num? ?? 0).toInt());
  final status = busy ? 'Testing…' : (online ? 'Online' : 'Offline');
  final dot = Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: online ? c.pos : c.neg, shape: BoxShape.circle, boxShadow: c.boxGlow(online ? c.pos : c.neg, 0.6)),
  );
  final quality = (mbps / 100).clamp(0.0, 1.0);
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : (c.sm ? 16 : 18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [dot, const SizedBox(width: 7), Expanded(child: Text(status, style: c.t(c.sm ? 13 : 15, dim: true))), if (!c.sm) Text(ago(at), style: c.t(12, dim: true))]),
      const Spacer(),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(child: fit(Text(mbps >= 10 ? mbps.toStringAsFixed(0) : mbps.toStringAsFixed(1), style: c.t(c.lg ? 96 : (c.sm ? 46 : 56), w: FontWeight.w600, h: 1)))),
        const SizedBox(width: 6),
        Text('Mbps', style: c.t(c.sm ? 13 : 16, dim: true)),
      ]),
      SizedBox(height: c.sm ? 8 : 12),
      if (!c.sm) ...[GlowBar(c, quality, height: c.lg ? 14 : 8), const SizedBox(height: 10)],
      Row(children: [
        Icon(CupertinoIcons.timer, size: 13, color: c.dim),
        const SizedBox(width: 4),
        Text('Ping $ping ms', style: c.t(13)),
        if (c.lg) ...[
          const Spacer(),
          Text(ping < 50 ? 'Great for calls & gaming' : ping < 120 ? 'Good for browsing' : 'Slow connection', style: c.t(13, dim: true)),
        ],
      ]),
    ]),
  );
}

// ───────────────────────── 23 GitHub ─────────────────────────

Widget _github(WCtx c) {
  final user = app.settings.githubUser;
  final key = 'gh:$user';
  app.hub.ensure(key, const Duration(hours: 1), () => Api.github(user));
  final j = app.hub.get<Map<String, dynamic>>(key);
  if (j == null) return _loading(c, CupertinoIcons.chevron_left_slash_chevron_right, 'GitHub · $user', key);
  final days = ((j['days'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final today = dkey(DateTime.now());
  final upTo = days.where((d) => '${d['d']}'.compareTo(today) <= 0).toList();
  final todayCount = upTo.isEmpty ? 0 : (upTo.last['c'] as num? ?? 0).toInt();
  var streak = 0;
  for (var i = upTo.length - 1; i >= 0; i--) {
    final cnt = (upTo[i]['c'] as num? ?? 0).toInt();
    if (cnt > 0) {
      streak++;
    } else if (i != upTo.length - 1) {
      break;
    }
  }
  final weeks = switch (c.size) { WSize.small => 7, WSize.medium => 20, WSize.large => 20 };
  final cells = upTo.length > weeks * 7 ? upTo.sublist(upTo.length - weeks * 7 - (DateTime.now().weekday % 7)) : upTo;

  Widget heat(double gap) => LayoutBuilder(builder: (context, bc) {
        final cols = (cells.length / 7).ceil();
        final sz = math.min((bc.maxWidth - gap * (cols - 1)) / cols, (bc.maxHeight - gap * 6) / 7);
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var col = 0; col < cols; col++)
              Padding(
                padding: EdgeInsets.only(left: col == 0 ? 0 : gap),
                child: Column(children: [
                  for (var r = 0; r < 7; r++)
                    Builder(builder: (context) {
                      final i = col * 7 + r;
                      final lvl = i < cells.length ? (cells[i]['l'] as num? ?? 0).toInt() : -1;
                      final color = lvl < 0
                          ? Colors.transparent
                          : lvl == 0
                              ? c.faint
                              : c.pos.withValues(alpha: 0.25 + lvl * 0.19);
                      return Container(
                        width: sz,
                        height: sz,
                        margin: EdgeInsets.only(top: r == 0 ? 0 : gap),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(sz * 0.28),
                          boxShadow: lvl >= 3 ? c.boxGlow(c.pos, 0.25) : null,
                        ),
                      );
                    }),
                ]),
              ),
          ],
        );
      });

  final total = j['total'] ?? 0;
  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.chevron_left_slash_chevron_right, user),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('$todayCount', style: c.t(34, w: FontWeight.w600)),
            const SizedBox(width: 5),
            Text('today · ${streak}d', style: c.t(12, dim: true)),
          ]),
          const SizedBox(height: 8),
          Expanded(child: heat(3)),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: WHeader(c, CupertinoIcons.chevron_left_slash_chevron_right, '$user · ${groupNum(total as num)} this year')),
            Text('$todayCount today', style: c.t(13)),
          ]),
          const SizedBox(height: 10),
          Expanded(child: heat(3)),
        ]),
      );
    case WSize.large:
      return WShell(
        c: c,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${j['name'] ?? user}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(24)),
          Text('@$user', style: c.t(14, dim: true)),
          const SizedBox(height: 16),
          Expanded(child: heat(3)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _kv(c, 'Contributions', groupNum(total as num))),
            Expanded(child: _kv(c, 'Streak', '$streak days')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _kv(c, 'Repositories', '${j['repos'] ?? '—'}')),
            Expanded(child: _kv(c, 'Followers', j['followers'] is num ? groupNum(j['followers'] as num) : '—')),
          ]),
        ]),
      );
  }
}

Widget _kv(WCtx c, String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: c.t(12, dim: true)),
      fit(Text(v, style: c.t(22))),
    ]);

class _GithubEditor extends StatelessWidget {
  const _GithubEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.settings,
        builder: (context, _) => Column(children: [
          Section(title: 'Account', children: [
            RowItem(
              icon: CupertinoIcons.person_fill,
              title: 'Username',
              value: app.settings.githubUser,
              onTap: () async {
                final u = await promptText(context, 'GitHub username', initial: app.settings.githubUser);
                if (u == null || u.isEmpty) return;
                app.settings.update(() => app.settings.githubUser = u.replaceAll('@', ''));
              },
            ),
          ]),
          RefreshRow('gh:${app.settings.githubUser}'),
        ]),
      );
}

// ───────────────────────── 24 Server Status ─────────────────────────

Future<List<Map<String, dynamic>>> _probeAll(List<String> urls) async =>
    Future.wait(urls.map(Api.probe));

Widget _statusRows(WCtx c, List<Map<String, dynamic>> res, List<String> names, int max, {bool ssl = false}) {
  final fs = c.sm ? 13.0 : 15.0;
  return Column(children: [
    for (var i = 0; i < math.min(max, res.length); i++)
      Expanded(
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: res[i]['ok'] == true ? c.pos : c.neg,
              boxShadow: c.boxGlow(res[i]['ok'] == true ? c.pos : c.neg, 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(names[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(fs))),
          if (ssl && !c.sm && res[i]['ssl'] != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text('SSL ${res[i]['ssl']}d', style: c.t(12, c: (res[i]['ssl'] as num) < 14 ? c.neg : c.dim, glow: false)),
            ),
          Text(res[i]['ok'] == true ? '${res[i]['ms']}ms' : (res[i]['code'] == 0 ? 'down' : '${res[i]['code']}'),
              style: c.t(fs, dim: res[i]['ok'] == true)),
        ]),
      ),
  ]);
}

Widget _server(WCtx c) {
  final list = app.store.list('servers');
  if (list.isEmpty) return WEmpty(c, CupertinoIcons.cloud_upload, 'Add a server or API endpoint.', title: 'Server Status');
  final urls = list.map((e) => '${e['u']}').toList();
  final key = 'servers:${urls.join('|')}';
  app.hub.ensure(key, const Duration(minutes: 5), () => _probeAll(urls));
  final res = (app.hub.get<List>(key) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (res.length != urls.length) return _loading(c, CupertinoIcons.cloud_upload, 'Server Status', key);
  final up = res.where((r) => r['ok'] == true).length;
  final names = list.map((e) => '${e['n']}').toList();
  final metrics = res.map((r) => r['metrics'] as Map?).whereType<Map>().firstOrNull;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : (c.sm ? 16 : 18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.cloud_upload_fill, c.sm ? 'Servers' : (up == res.length ? 'All systems normal' : '${res.length - up} down'), trailing: '$up/${res.length}'),
      if (c.lg) ...[
        const SizedBox(height: 12),
        Text(up == res.length ? 'Operational' : 'Degraded', style: c.script(44, c: up == res.length ? c.fg : c.neg)),
        if (metrics != null) ...[
          const SizedBox(height: 8),
          for (final k in ['cpu', 'ram', 'memory', 'disk'])
            if (metrics[k] is num)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  SizedBox(width: 50, child: Text(k.toUpperCase(), style: c.t(12, dim: true))),
                  Expanded(child: GlowBar(c, (metrics[k] as num) / 100, height: 6)),
                  SizedBox(width: 44, child: Text('${(metrics[k] as num).round()}%', textAlign: TextAlign.right, style: c.t(12))),
                ]),
              ),
        ],
      ],
      const SizedBox(height: 6),
      Expanded(child: _statusRows(c, res, names, c.sm ? 3 : (c.md ? 3 : 6))),
    ]),
  );
}

class _UrlListEditor extends StatelessWidget {
  const _UrlListEditor({required this.storeKey, required this.hubKey, required this.title, required this.withName, this.footer});
  final String storeKey, hubKey, title;
  final bool withName;
  final String? footer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final items = withName ? app.store.list(storeKey) : [for (final s in app.store.strs(storeKey)) {'n': s, 'u': s}];
          void save(List<Map<String, dynamic>> v) =>
              app.store.set(storeKey, withName ? v : v.map((e) => '${e['u']}').toList());
          return Column(children: [
            ListEditor(
              title: title,
              items: items,
              titleOf: (m) => '${m['n']}',
              subtitleOf: (m) => withName ? '${m['u']}' : '',
              addLabel: 'Add',
              footer: footer,
              onAdd: () async {
                if (withName) {
                  final r = await promptFields(context, title: 'New endpoint', labels: ['Name', 'URL (https://…)'], keyboards: [null, TextInputType.url]);
                  if (r == null || r[1].isEmpty) return;
                  save([...items, {'n': r[0].isEmpty ? r[1] : r[0], 'u': r[1]}]);
                } else {
                  final r = await promptText(context, 'Website', placeholder: 'example.com', keyboard: TextInputType.url);
                  if (r == null || r.isEmpty) return;
                  save([...items, {'n': r, 'u': r}]);
                }
              },
              onDelete: (i) => save([...items]..removeAt(i)),
            ),
            Section(children: [
              RowItem(
                icon: CupertinoIcons.arrow_clockwise,
                iconColor: const Color(0xFF3A3A3C),
                title: 'Check now',
                chevron: false,
                onTap: () {
                  final urls = items.map((e) => '${e['u']}').toList();
                  app.hub.invalidate('$hubKey:${urls.join('|')}');
                },
              ),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 25 Crypto ─────────────────────────

Widget _crypto(WCtx c) {
  final ids = app.store.strs('crypto.ids');
  if (ids.isEmpty) return WEmpty(c, CupertinoIcons.bitcoin_circle, 'Add coins to watch.', title: 'Crypto');
  final key = 'crypto:${ids.join(',')}';
  app.hub.ensure(key, const Duration(minutes: 5), () => Api.crypto(ids));
  final raw = app.hub.get<List>(key);
  if (raw == null) return _loading(c, CupertinoIcons.bitcoin_circle, 'Crypto', key);
  final coins = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (coins.isEmpty) return WEmpty(c, CupertinoIcons.bitcoin_circle, 'No coins found.', title: 'Crypto');
  List<double> spark(Map<String, dynamic> m) {
    final p = ((m['sparkline_in_7d'] as Map?)?['price'] as List?) ?? [];
    final v = p.map((e) => (e as num).toDouble()).toList();
    if (v.length <= 40) return v;
    final step = v.length / 40;
    return [for (var i = 0; i < 40; i++) v[(i * step).floor()]];
  }

  double ch(Map<String, dynamic> m) => (m['price_change_percentage_24h'] as num? ?? 0).toDouble();
  String sym(Map<String, dynamic> m) => '${m['symbol']}'.toUpperCase();
  double price(Map<String, dynamic> m) => (m['current_price'] as num? ?? 0).toDouble();

  if (c.sm) {
    final m = coins.first;
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(sym(m), style: c.t(15, dim: true)),
          const Spacer(),
          Text(pct(ch(m)), style: c.t(13, c: _chg(c, ch(m)))),
        ]),
        fit(Text(money(price(m)), style: c.t(30, w: FontWeight.w600))),
        const SizedBox(height: 8),
        Expanded(child: Spark(c, spark(m), color: _chg(c, ch(m)))),
      ]),
    );
  }
  final max = c.md ? 3 : 6;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 20 : 16),
    child: Column(children: [
      if (c.lg) ...[WHeader(c, CupertinoIcons.bitcoin_circle_fill, 'Market · 24h'), const SizedBox(height: 6)],
      for (final m in coins.take(max))
        Expanded(
          child: Row(children: [
            SizedBox(width: 52, child: Text(sym(m), style: c.t(15))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Spark(c, spark(m), color: _chg(c, ch(m)), fill: false, stroke: 1.6))),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                fit(Text(money(price(m)), style: c.t(15)), a: Alignment.centerRight),
                Text(pct(ch(m)), style: c.t(12, c: _chg(c, ch(m)), glow: false)),
              ]),
            ),
          ]),
        ),
    ]),
  );
}

class _SymbolsEditor extends StatelessWidget {
  const _SymbolsEditor({required this.storeKey, required this.hubPrefix, required this.title, required this.hint, this.upper = false, this.footer});
  final String storeKey, hubPrefix, title, hint;
  final bool upper;
  final String? footer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final items = app.store.strs(storeKey);
          return ListEditor(
            title: title,
            items: [for (final s in items) {'s': s}],
            titleOf: (m) => '${m['s']}',
            addLabel: 'Add',
            footer: footer,
            onAdd: () async {
              final r = await promptText(context, 'Add', placeholder: hint);
              if (r == null || r.isEmpty) return;
              final v = upper ? r.toUpperCase() : r.toLowerCase();
              if (!items.contains(v)) app.store.set(storeKey, [...items, v]);
            },
            onDelete: (i) => app.store.set(storeKey, [...items]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 26 Currency ─────────────────────────

Widget _currency(WCtx c) {
  final base = app.store.str('fx.base', 'USD');
  final pairs = app.store.strs('fx.pairs');
  final key = 'fx:$base';
  app.hub.ensure(key, const Duration(hours: 3), () => Api.currency(base));
  final j = app.hub.get<Map<String, dynamic>>(key);
  if (j == null) return _loading(c, CupertinoIcons.money_dollar_circle, 'Currency', key);
  final rates = Map<String, dynamic>.from(j['rates'] as Map? ?? {});
  String fmt(num v) => v >= 100 ? groupNum(v) : v >= 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(4);
  final first = pairs.isEmpty ? null : pairs.first;
  if (c.sm && first != null) {
    final v = rates[first] as num? ?? 0;
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('1 $base', style: c.t(15, dim: true)),
        const Spacer(),
        fit(Text(fmt(v), style: c.t(40, w: FontWeight.w600))),
        Text(first, style: c.t(15, dim: true)),
        const SizedBox(height: 8),
        if (pairs.length > 1) Text('${pairs[1]} ${fmt(rates[pairs[1]] as num? ?? 0)}', style: c.t(13)),
      ]),
    );
  }
  final max = c.md ? 3 : 7;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('1 $base', style: c.t(c.lg ? 18 : 14, dim: true)),
        const Spacer(),
        Text('${j['time_last_update_utc'] ?? ''}'.split(' ').skip(1).take(2).join(' '), style: c.t(12, dim: true)),
      ]),
      if (c.lg && first != null) ...[
        const SizedBox(height: 8),
        fit(Text('${fmt(rates[first] as num? ?? 0)} $first', style: c.t(46, w: FontWeight.w600))),
        Divider(color: c.line, height: 24),
      ],
      for (final p in pairs.skip(c.lg ? 1 : 0).take(max))
        Expanded(
          child: Row(children: [
            Text(p, style: c.t(c.lg ? 17 : 15, dim: true)),
            const Spacer(),
            Text(fmt(rates[p] as num? ?? 0), style: c.t(c.lg ? 22 : 18)),
          ]),
        ),
    ]),
  );
}

class _CurrencyEditor extends StatelessWidget {
  const _CurrencyEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final pairs = app.store.strs('fx.pairs');
          return Column(children: [
            Section(title: 'Base', children: [
              RowItem(
                title: 'Base currency',
                value: app.store.str('fx.base', 'USD'),
                onTap: () async {
                  final r = await promptText(context, 'Base currency', initial: app.store.str('fx.base', 'USD'), placeholder: 'USD');
                  if (r == null || r.length != 3) return;
                  app.store.set('fx.base', r.toUpperCase());
                },
              ),
            ]),
            ListEditor(
              title: 'Currencies',
              items: [for (final p in pairs) {'p': p}],
              titleOf: (m) => '${m['p']}',
              addLabel: 'Add currency',
              footer: 'ISO codes like UZS, EUR, JPY. Rates via ExchangeRate-API.',
              onAdd: () async {
                final r = await promptText(context, 'Currency code', placeholder: 'e.g. JPY');
                if (r == null || r.length != 3) return;
                app.store.set('fx.pairs', [...pairs, r.toUpperCase()]);
              },
              onDelete: (i) => app.store.set('fx.pairs', [...pairs]..removeAt(i)),
            ),
          ]);
        },
      );
}

// ───────────────────────── 27 Stocks ─────────────────────────

Widget _stocks(WCtx c) {
  final syms = app.store.strs('stocks');
  if (syms.isEmpty) return WEmpty(c, CupertinoIcons.graph_square, 'Add tickers to watch.', title: 'Stocks');
  final key = 'stocks:${syms.join(',')}';
  app.hub.ensure(key, const Duration(minutes: 10), () => Api.stocks(syms));
  final raw = app.hub.get<List>(key);
  if (raw == null) return _loading(c, CupertinoIcons.graph_square, 'Stocks', key);
  final qs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  double ch(Map<String, dynamic> q) => ((q['c'] as num) - (q['o'] as num)) / (q['o'] as num) * 100;
  if (c.sm) {
    final q = qs.first;
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${q['s']}', style: c.t(18)),
        Text(pct(ch(q)), style: c.t(13, c: _chg(c, ch(q)))),
        const Spacer(),
        fit(Text(money(q['c'] as num), style: c.t(34, w: FontWeight.w600))),
        const SizedBox(height: 8),
        _dayRange(c, q),
      ]),
    );
  }
  final max = c.md ? 3 : 7;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 20 : 16),
    child: Column(children: [
      if (c.lg) ...[WHeader(c, CupertinoIcons.graph_square_fill, 'Watchlist · today'), const SizedBox(height: 6)],
      for (final q in qs.take(max))
        Expanded(
          child: Row(children: [
            SizedBox(width: 64, child: Text('${q['s']}', style: c.t(16))),
            Expanded(child: _dayRange(c, q)),
            const SizedBox(width: 12),
            SizedBox(width: 82, child: fit(Text(money(q['c'] as num), style: c.t(15)), a: Alignment.centerRight)),
            const SizedBox(width: 8),
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _chg(c, ch(q)).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(7)),
              child: Text(pct(ch(q)), style: c.t(12, c: _chg(c, ch(q)), glow: false)),
            ),
          ]),
        ),
    ]),
  );
}

Widget _dayRange(WCtx c, Map<String, dynamic> q) {
  final l = (q['l'] as num).toDouble(), h = (q['h'] as num).toDouble(), cl = (q['c'] as num).toDouble();
  final f = h == l ? 0.5 : (cl - l) / (h - l);
  return LayoutBuilder(builder: (context, bc) => SizedBox(
        height: 10,
        child: Stack(children: [
          Positioned(left: 0, right: 0, top: 4, height: 2, child: ColoredBox(color: c.line)),
          Positioned(
            left: (bc.maxWidth - 10) * f,
            top: 0,
            width: 10,
            height: 10,
            child: DecoratedBox(decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle, boxShadow: c.boxGlow(c.fg, 0.4))),
          ),
        ]),
      ));
}

// ───────────────────────── 28 Package Tracker ─────────────────────────

const _stages = ['Ordered', 'Shipped', 'In transit', 'Out for delivery', 'Delivered'];

Widget _parcels(WCtx c) {
  final ps = app.store.list('parcels');
  if (ps.isEmpty) return WEmpty(c, CupertinoIcons.cube_box, 'Add a parcel to track.', title: 'Packages');
  Widget steps(int stage, double h) => Row(children: [
        for (var i = 0; i < _stages.length; i++)
          Expanded(
            child: Container(
              height: h,
              margin: EdgeInsets.only(right: i < _stages.length - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: i <= stage ? (stage == 4 ? c.pos : c.fg) : c.faint,
                borderRadius: BorderRadius.circular(h),
                boxShadow: i == stage ? c.boxGlow(stage == 4 ? c.pos : c.fg, 0.5) : null,
              ),
            ),
          ),
      ]);
  Widget item(Map<String, dynamic> p, double fs) {
    final st = (p['stage'] as num? ?? 0).toInt().clamp(0, 4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('${p['n']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(fs)),
      const SizedBox(height: 2),
      Text(_stages[st], style: c.t(fs - 3, c: st == 4 ? c.pos : c.dim, glow: false)),
      SizedBox(height: fs * 0.5),
      steps(st, 5),
    ]);
  }

  if (c.sm) {
    final p = ps.first;
    final st = (p['stage'] as num? ?? 0).toInt().clamp(0, 4);
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.cube_box_fill, '${ps.length} active'),
        const Spacer(),
        Text(_stages[st], maxLines: 2, style: c.t(22, h: 1.1)),
        Text('${p['n']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(13, dim: true)),
        const SizedBox(height: 10),
        steps(st, 6),
      ]),
    );
  }
  final max = c.md ? 2 : 5;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.cube_box_fill, 'Packages', trailing: '${ps.length}'),
      for (final p in ps.take(max)) Expanded(child: Align(alignment: Alignment.centerLeft, child: item(p, c.lg ? 17 : 15))),
    ]),
  );
}

class _ParcelEditor extends StatelessWidget {
  const _ParcelEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final ps = app.store.list('parcels');
          return ListEditor(
            title: 'Parcels',
            items: ps,
            titleOf: (m) => '${m['n']}',
            subtitleOf: (m) => '${_stages[(m['stage'] as num? ?? 0).toInt().clamp(0, 4)]} · ${m['code']}',
            addLabel: 'Add parcel',
            footer: 'Tap a parcel to move it to the next stage. Swipe left to delete.',
            onTap: (i) {
              ps[i]['stage'] = (((ps[i]['stage'] as num? ?? 0).toInt() + 1) % 5);
              app.store.set('parcels', ps);
            },
            onAdd: () async {
              final r = await promptFields(context, title: 'New parcel', labels: ['Name', 'Tracking code']);
              if (r == null || r[0].isEmpty) return;
              app.store.set('parcels', [...ps, {'n': r[0], 'code': r[1], 'stage': 0}]);
            },
            onDelete: (i) => app.store.set('parcels', [...ps]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 29 Website Monitor ─────────────────────────

Widget _sites(WCtx c) {
  final sites = app.store.strs('sites');
  if (sites.isEmpty) return WEmpty(c, CupertinoIcons.lock_shield, 'Add websites to monitor.', title: 'Websites');
  final key = 'sites:${sites.join('|')}';
  app.hub.ensure(key, const Duration(minutes: 10), () => _probeAll(sites));
  final res = (app.hub.get<List>(key) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (res.length != sites.length) return _loading(c, CupertinoIcons.lock_shield, 'Websites', key);
  final up = res.where((r) => r['ok'] == true).length;
  final avg = res.where((r) => r['ok'] == true).fold<int>(0, (a, r) => a + (r['ms'] as num).toInt()) ~/ math.max(1, up);
  final names = res.map((r) => '${r['host']}').toList();
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.lock_shield_fill, 'Uptime'),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$up/${res.length}', style: c.t(32, w: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${avg}ms', style: c.t(12, dim: true)),
        ]),
        const SizedBox(height: 4),
        Expanded(child: _statusRows(c, res, names, 3)),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.lock_shield_fill, up == res.length ? 'All sites up' : '${res.length - up} down', trailing: 'avg ${avg}ms'),
      const SizedBox(height: 6),
      Expanded(child: _statusRows(c, res, names, c.md ? 3 : 8, ssl: true)),
    ]),
  );
}

// ───────────────────────── 30 Dev Feed ─────────────────────────

Widget _devfeed(WCtx c) {
  final repos = app.store.strs('repos');
  if (repos.isEmpty) return WEmpty(c, CupertinoIcons.tag, 'Follow some repositories.', title: 'Dev Feed');
  final key = 'repos:${repos.join(',')}';
  app.hub.ensure(key, const Duration(hours: 2), () => Api.releases(repos));
  final raw = app.hub.get<List>(key);
  if (raw == null) return _loading(c, CupertinoIcons.tag, 'Dev Feed', key);
  final rs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final max = switch (c.size) { WSize.small => 2, WSize.medium => 3, WSize.large => 7 };
  String when(Map<String, dynamic> r) {
    final at = DateTime.tryParse('${r['at']}');
    return at == null ? '' : ago(at);
  }

  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.tag_fill, 'Releases'),
      const SizedBox(height: 4),
      for (final r in rs.take(max))
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Expanded(child: Text('${r['r']}'.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 14 : 16))),
              Text(when(r), style: c.t(11, dim: true)),
            ]),
            Text('${r['tag']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.mono(c.sm ? 11 : 12, c: c.pos, dim: false)),
          ]),
        ),
    ]),
  );
}

// ───────────────────────── One-row glances ─────────────────────────

List<Map<String, dynamic>> _hubList(String key) =>
    (app.hub.get<List>(key) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Glance _upGlance(List<Map<String, dynamic>> res, int expected, String what, IconData icon, WCtx c) {
  if (res.length != expected || res.isEmpty) return Glance('—', label: 'Checking $what…', icon: icon);
  final up = res.where((r) => r['ok'] == true).length;
  final avg = res.where((r) => r['ok'] == true).fold<int>(0, (a, r) => a + (r['ms'] as num).toInt()) ~/ math.max(1, up);
  return Glance('$up/${res.length} up', label: up == res.length ? 'All $what normal · ${avg}ms' : '${res.length - up} down', icon: icon, color: up == res.length ? c.pos : c.neg);
}

final digitalGlances = <String, Glance Function(WCtx)>{
  'pulse': (c) {
    final net = app.hub.get<Map<String, dynamic>>('net');
    return Glance('${(ProcessInfo.currentRss / 1024 / 1024).round()} MB',
        label: 'App memory · ${Platform.numberOfProcessors} cores${net == null ? '' : ' · ${net['ping']} ms'}',
        icon: CupertinoIcons.waveform_path_ecg);
  },
  'network': (c) {
    final net = app.hub.get<Map<String, dynamic>>('net');
    if (net == null) return const Glance('—', label: 'Testing connection…', icon: CupertinoIcons.wifi);
    final mbps = (net['mbps'] as num? ?? 0).toDouble();
    return Glance('${mbps >= 10 ? mbps.toStringAsFixed(0) : mbps.toStringAsFixed(1)} Mbps',
        label: 'Ping ${net['ping']} ms', icon: CupertinoIcons.wifi, color: app.hub.error('net') == null ? null : c.neg);
  },
  'github': (c) {
    final user = app.settings.githubUser;
    final j = app.hub.get<Map<String, dynamic>>('gh:$user');
    if (j == null) return Glance('@$user', label: 'Loading contributions…', icon: CupertinoIcons.chevron_left_slash_chevron_right);
    final today = dkey(DateTime.now());
    final days = ((j['days'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).where((d) => '${d['d']}'.compareTo(today) <= 0).toList();
    final todayCount = days.isEmpty ? 0 : (days.last['c'] as num? ?? 0).toInt();
    return Glance('$todayCount today', label: '${groupNum(j['total'] as num? ?? 0)} this year · @$user', icon: CupertinoIcons.chevron_left_slash_chevron_right, color: c.pos);
  },
  'server': (c) {
    final urls = app.store.list('servers').map((e) => '${e['u']}').toList();
    return _upGlance(_hubList('servers:${urls.join('|')}'), urls.length, 'systems', CupertinoIcons.cloud_upload_fill, c);
  },
  'crypto': (c) {
    final ids = app.store.strs('crypto.ids');
    final coins = _hubList('crypto:${ids.join(',')}');
    if (coins.isEmpty) return const Glance('—', label: 'Loading market…', icon: CupertinoIcons.bitcoin_circle_fill);
    final m = coins.first;
    final ch = (m['price_change_percentage_24h'] as num? ?? 0).toDouble();
    return Glance(money(m['current_price'] as num? ?? 0),
        label: '${'${m['symbol']}'.toUpperCase()} ${pct(ch)} · ${coins.skip(1).take(2).map((e) => '${'${e['symbol']}'.toUpperCase()} ${money(e['current_price'] as num? ?? 0)}').join(' · ')}',
        icon: CupertinoIcons.bitcoin_circle_fill, color: _chg(c, ch));
  },
  'currency': (c) {
    final base = app.store.str('fx.base', 'USD');
    final pairs = app.store.strs('fx.pairs');
    final j = app.hub.get<Map<String, dynamic>>('fx:$base');
    if (j == null || pairs.isEmpty) return Glance('1 $base', label: 'Loading rates…', icon: CupertinoIcons.money_dollar_circle_fill);
    final rates = Map<String, dynamic>.from(j['rates'] as Map? ?? {});
    String f(num v) => v >= 100 ? groupNum(v) : v.toStringAsFixed(v >= 1 ? 2 : 4);
    return Glance('${f(rates[pairs.first] as num? ?? 0)} ${pairs.first}',
        label: '1 $base · ${pairs.skip(1).take(2).map((p) => '$p ${f(rates[p] as num? ?? 0)}').join(' · ')}',
        icon: CupertinoIcons.money_dollar_circle_fill);
  },
  'stocks': (c) {
    final syms = app.store.strs('stocks');
    final qs = _hubList('stocks:${syms.join(',')}');
    if (qs.isEmpty) return const Glance('—', label: 'Loading quotes…', icon: CupertinoIcons.graph_square_fill);
    double ch(Map<String, dynamic> q) => ((q['c'] as num) - (q['o'] as num)) / (q['o'] as num) * 100;
    return Glance('${qs.first['s']} ${money(qs.first['c'] as num)}',
        label: '${pct(ch(qs.first))} · ${qs.skip(1).take(2).map((q) => '${q['s']} ${pct(ch(q))}').join(' · ')}',
        icon: CupertinoIcons.graph_square_fill, color: _chg(c, ch(qs.first)));
  },
  'parcels': (c) {
    final ps = app.store.list('parcels');
    if (ps.isEmpty) return const Glance('—', label: 'No parcels', icon: CupertinoIcons.cube_box_fill);
    final st = (ps.first['stage'] as num? ?? 0).toInt().clamp(0, 4);
    return Glance(_stages[st], label: '${ps.first['n']}', icon: CupertinoIcons.cube_box_fill, progress: (st + 1) / 5, color: st == 4 ? c.pos : null);
  },
  'sites': (c) {
    final sites = app.store.strs('sites');
    return _upGlance(_hubList('sites:${sites.join('|')}'), sites.length, 'sites', CupertinoIcons.lock_shield_fill, c);
  },
  'devfeed': (c) {
    final repos = app.store.strs('repos');
    final rs = _hubList('repos:${repos.join(',')}');
    if (rs.isEmpty) return const Glance('—', label: 'Loading releases…', icon: CupertinoIcons.tag_fill);
    final at = DateTime.tryParse('${rs.first['at']}');
    return Glance('${'${rs.first['r']}'.split('/').last} ${rs.first['tag']}', label: at == null ? 'Latest release' : 'Released ${ago(at)}', icon: CupertinoIcons.tag_fill);
  },
};