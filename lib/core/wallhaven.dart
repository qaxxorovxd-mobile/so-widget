import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'state.dart';

/// Wallpapers from Wallhaven (https://wallhaven.cc). Only SFW content is ever requested.
/// Images are streamed straight from Wallhaven to the device; nothing is re-hosted.
const kWallhaven = 'https://wallhaven.cc';
const _ua = {'User-Agent': 'SoWidget/1.2 (+https://qaxxorov.uz)'};

// ───────────────────────── Model ─────────────────────────

class Wall {
  Wall({
    required this.id,
    required this.url,
    required this.path,
    required this.thumb,
    required this.w,
    required this.h,
    this.size = 0,
    this.views = 0,
    this.favorites = 0,
    this.fileType = 'image/jpeg',
    this.source = '',
    this.category = '',
    this.created = '',
    this.colors = const [],
  });

  final String id, url, path, thumb, fileType, source, category, created;
  final int w, h, size, views, favorites;
  final List<String> colors;

  factory Wall.fromJson(Map<String, dynamic> j) {
    final thumbs = j['thumbs'] is Map ? Map<String, dynamic>.from(j['thumbs'] as Map) : const <String, dynamic>{};
    int i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return Wall(
      id: '${j['id']}',
      url: '${j['url'] ?? '$kWallhaven/w/${j['id']}'}',
      path: '${j['path']}',
      thumb: '${thumbs['original'] ?? j['thumb'] ?? thumbs['large'] ?? ''}',
      w: i(j['dimension_x'] ?? j['w']),
      h: i(j['dimension_y'] ?? j['h']),
      size: i(j['file_size'] ?? j['size']),
      views: i(j['views']),
      favorites: i(j['favorites']),
      fileType: '${j['file_type'] ?? 'image/jpeg'}',
      source: '${j['source'] ?? ''}',
      category: '${j['category'] ?? ''}',
      created: '${j['created_at'] ?? j['created'] ?? ''}',
      colors: (j['colors'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'path': path,
        'thumb': thumb,
        'w': w,
        'h': h,
        'size': size,
        'views': views,
        'favorites': favorites,
        'file_type': fileType,
        'source': source,
        'category': category,
        'created': created,
        'colors': colors,
      };

  String get ext => fileType.contains('png') ? 'png' : 'jpg';
  String get fileName => 'wallhaven-$id.$ext';
  double get aspect => h == 0 ? 0.5625 : w / h;

  String get quality {
    final s = min(w, h);
    if (s >= 2160) return '4K';
    if (s >= 1440) return 'QHD+';
    if (s >= 1080) return 'FHD';
    return 'HD';
  }

  String get sizeLabel {
    if (size <= 0) return '';
    final mb = size / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(size / 1024).round()} KB';
  }

  /// Weighted perceived lightness (0 = black, 1 = white) of the palette Wallhaven extracted.
  double get luma {
    if (colors.isEmpty) return 0.5;
    var sum = 0.0, wsum = 0.0;
    for (var k = 0; k < colors.length; k++) {
      final weight = (colors.length - k).toDouble();
      sum += lumaOf(colors[k]) * weight;
      wsum += weight;
    }
    return sum / wsum;
  }

  double get dominantLuma => colors.isEmpty ? 0.5 : lumaOf(colors.first);
}

double lumaOf(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length < 6) return 0.5;
  final v = int.tryParse(h.substring(0, 6), radix: 16) ?? 0x808080;
  final r = (v >> 16 & 255) / 255, g = (v >> 8 & 255) / 255, b = (v & 255) / 255;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// ───────────────────────── Filters ─────────────────────────

enum WSort {
  popular('favorites', 'Popular'),
  top('toplist', 'Top'),
  latest('date_added', 'Latest'),
  views('views', 'Most viewed'),
  random('random', 'Random');

  const WSort(this.api, this.label);
  final String api, label;
}

enum WRange {
  week('1w', 'Week'),
  month('1M', 'Month'),
  quarter('3M', '3 months'),
  year('1y', 'Year');

  const WRange(this.api, this.label);
  final String api, label;
}

enum WFit {
  phone('9x16,9x18,9x19.5,9x20,9x21', 'Phone'),
  portrait('portrait', 'Any portrait');

  const WFit(this.api, this.label);
  final String api, label;
}

enum WQuality {
  uhd(2160, 3840, '4K'),
  qhd(1440, 2560, 'QHD+'),
  fhd(1080, 1920, 'Full HD');

  const WQuality(this.w, this.h, this.label);
  final int w, h;
  final String label;
  String get api => '${w}x$h';
}

enum WTone {
  any('Any'),
  dark('Dark'),
  amoled('AMOLED');

  const WTone(this.label);
  final String label;

  bool accepts(Wall w) => switch (this) {
        WTone.any => true,
        // Wallhaven's palette is ordered by coverage and always lists a few accent colours,
        // so the dominant colour decides and the weighted average only guards against bright images.
        WTone.dark => w.dominantLuma <= 0.3 && w.luma <= 0.42,
        WTone.amoled => w.dominantLuma <= 0.05 && (w.colors.length < 2 || lumaOf(w.colors[1]) <= 0.3),
      };
}

/// The colour palette Wallhaven accepts for its `colors` filter.
const kWallColors = [
  '000000', '424153', '333399', '663399', '993399', '660066', '0066cc', '0099cc', '66cccc', '336600', //
  '669900', '77cc33', '666600', '999900', 'cccc33', 'ffff00', 'ffcc33', 'ff9900', 'ff6600', 'cc6633',
  '996633', '663300', '660000', '990000', 'cc0000', 'cc3333', 'ea4c88', '999999', 'cccccc', 'ffffff',
];

@immutable
class WFilters {
  const WFilters({
    this.sort = WSort.popular,
    this.range = WRange.month,
    this.fit = WFit.portrait,
    this.quality = WQuality.uhd,
    this.tone = WTone.any,
    this.color,
    this.general = true,
    this.anime = false,
    this.people = false,
  });

  final WSort sort;
  final WRange range;
  final WFit fit;
  final WQuality quality;
  final WTone tone;
  final String? color;
  final bool general, anime, people;

  static const defaults = WFilters();

  String get categories {
    final s = '${general ? 1 : 0}${anime ? 1 : 0}${people ? 1 : 0}';
    return s == '000' ? '100' : s;
  }

  int get activeCount {
    const d = defaults;
    return [
      sort != d.sort,
      fit != d.fit,
      quality != d.quality,
      tone != d.tone,
      color != null,
      categories != d.categories,
    ].where((e) => e).length;
  }

  WFilters copyWith({
    WSort? sort,
    WRange? range,
    WFit? fit,
    WQuality? quality,
    WTone? tone,
    String? color,
    bool clearColor = false,
    bool? general,
    bool? anime,
    bool? people,
  }) =>
      WFilters(
        sort: sort ?? this.sort,
        range: range ?? this.range,
        fit: fit ?? this.fit,
        quality: quality ?? this.quality,
        tone: tone ?? this.tone,
        color: clearColor ? null : (color ?? this.color),
        general: general ?? this.general,
        anime: anime ?? this.anime,
        people: people ?? this.people,
      );

  Map<String, dynamic> toJson() => {
        'sort': sort.name,
        'range': range.name,
        'fit': fit.name,
        'quality': quality.name,
        'tone': tone.name,
        'color': color,
        'general': general,
        'anime': anime,
        'people': people,
      };

  factory WFilters.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> all, Object? n, T def) => all.firstWhere((e) => e.name == n, orElse: () => def);
    const d = defaults;
    return WFilters(
      sort: pick(WSort.values, j['sort'], d.sort),
      range: pick(WRange.values, j['range'], d.range),
      fit: pick(WFit.values, j['fit'], d.fit),
      quality: pick(WQuality.values, j['quality'], d.quality),
      tone: pick(WTone.values, j['tone'], d.tone),
      color: j['color'] is String && kWallColors.contains(j['color']) ? j['color'] as String : null,
      general: j['general'] != false,
      anime: j['anime'] == true,
      people: j['people'] == true,
    );
  }
}

/// A mood preset. Combines a Wallhaven query with optional overrides and an on-device tone check.
class Vibe {
  const Vibe(this.name, this.q, this.tint, {this.categories, this.color, this.tone = WTone.any, this.sort, this.range});
  final String name, q;
  final List<int> tint;
  final String? categories, color;
  final WTone tone;
  final WSort? sort;
  final WRange? range;
}

const kVibes = <Vibe>[
  Vibe('Dark', 'dark', [0xFF2C2C2E, 0xFF000000], tone: WTone.dark),
  Vibe('AMOLED', '', [0xFF000000, 0xFF1C1C1E], color: '000000', tone: WTone.amoled),
  Vibe('Minimal', 'minimalism', [0xFFE5E5EA, 0xFF636366]),
  Vibe('Trending', '', [0xFFFFFFFF, 0xFF8E8E93], sort: WSort.top, range: WRange.month),
  Vibe('Neon', 'neon', [0xFFFF2D95, 0xFF5E5CE6]),
  Vibe('Cyberpunk', 'cyberpunk', [0xFFFFD60A, 0xFFFF2D55]),
  Vibe('Space', 'space', [0xFF5E5CE6, 0xFF000000]),
  Vibe('Night', 'night', [0xFF0A84FF, 0xFF001A33]),
  Vibe('Nature', 'nature', [0xFF30D158, 0xFF0B3D1E]),
  Vibe('Mountains', 'mountains', [0xFF8E9AAF, 0xFF2B3A55]),
  Vibe('Ocean', 'sea', [0xFF64D2FF, 0xFF0A3D62]),
  Vibe('Sunset', 'sunset', [0xFFFF9F0A, 0xFFFF375F]),
  Vibe('City', 'city', [0xFFFFCC66, 0xFF2C2C54]),
  Vibe('Rain', 'rain', [0xFF7D8FA3, 0xFF22303C]),
  Vibe('Abstract', 'abstract', [0xFFBF5AF2, 0xFF0A84FF]),
  Vibe('Digital Art', 'digital art', [0xFF5AC8FA, 0xFFAF52DE]),
  Vibe('Flowers', 'flowers', [0xFFFF6482, 0xFFFFD1DC]),
  Vibe('Cars', 'cars', [0xFFFF453A, 0xFF1C1C1E]),
  Vibe('Pixel Art', 'pixel art', [0xFF32D74B, 0xFF5E5CE6]),
  Vibe('Anime', 'anime', [0xFFFF9FC6, 0xFF7A5CFF], categories: '010'),
];

// ───────────────────────── API ─────────────────────────

class WallhavenBusy implements Exception {
  @override
  String toString() => 'Wallhaven is busy right now. Try again in a few seconds.';
}

class WallPage {
  WallPage(this.items, this.page, this.lastPage, this.total);
  final List<Wall> items;
  final int page, lastPage, total;
}

class Wallhaven {
  static final _cache = <String, WallPage>{};
  static final _info = <String, Map<String, dynamic>>{};

  static Map<String, String> params({
    required String q,
    required WFilters f,
    String? categories,
    String? color,
    WSort? sort,
    WRange? range,
    int page = 1,
    String? seed,
  }) {
    final s = sort ?? f.sort;
    return {
      if (q.isNotEmpty) 'q': q,
      'categories': categories ?? f.categories,
      'purity': '100',
      'sorting': s.api,
      if (s == WSort.top) 'topRange': (range ?? f.range).api,
      'order': 'desc',
      'atleast': f.quality.api,
      'ratios': f.fit.api,
      if ((color ?? f.color) != null) 'colors': (color ?? f.color)!,
      if (s == WSort.random && seed != null) 'seed': seed,
      'page': '$page',
    };
  }

  static Future<WallPage> search(Map<String, String> p) async {
    final uri = Uri.https('wallhaven.cc', '/api/v1/search', p);
    final key = uri.toString();
    final hit = _cache[key];
    if (hit != null) return hit;
    for (var attempt = 0;; attempt++) {
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 20));
      if (r.statusCode == 429) {
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: 2 + attempt * 3));
          continue;
        }
        throw WallhavenBusy();
      }
      if (r.statusCode >= 400) throw Exception('Wallhaven HTTP ${r.statusCode}');
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      final meta = Map<String, dynamic>.from(j['meta'] as Map? ?? {});
      final items = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Wall.fromJson(Map<String, dynamic>.from(e)))
          .where((w) => w.path.startsWith('https://'))
          .toList();
      int n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      final page = WallPage(items, n(meta['current_page']), max(1, n(meta['last_page'])), n(meta['total']));
      if (p['sorting'] != 'random') _cache[key] = page;
      return page;
    }
  }

  /// Uploader and tags (one extra request, cached).
  static Future<Map<String, dynamic>> info(String id) async {
    final hit = _info[id];
    if (hit != null) return hit;
    final r = await http.get(Uri.parse('$kWallhaven/api/v1/w/$id'), headers: _ua).timeout(const Duration(seconds: 20));
    if (r.statusCode == 429) throw WallhavenBusy();
    if (r.statusCode >= 400) throw Exception('Wallhaven HTTP ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
    final d = Map<String, dynamic>.from(j['data'] as Map);
    if (d['purity'] != 'sfw') throw Exception('Not available');
    return _info[id] = d;
  }

  static String uploaderOf(Map<String, dynamic> info) =>
      '${(info['uploader'] as Map?)?['username'] ?? ''}';

  static String? avatarOf(Map<String, dynamic> info) {
    final a = (info['uploader'] as Map?)?['avatar'];
    return a is Map ? '${a['128px'] ?? a['200px'] ?? ''}' : null;
  }

  static List<({int id, String name})> tagsOf(Map<String, dynamic> info) => (info['tags'] as List? ?? [])
      .whereType<Map>()
      .where((t) => t['purity'] == 'sfw')
      .map((t) => (id: (t['id'] as num).toInt(), name: '${t['name']}'))
      .toList();
}

// ───────────────────────── Feed ─────────────────────────

class WallFeed extends ChangeNotifier {
  WallFeed() {
    final saved = app.store.map('wall.filters');
    filters = saved.isEmpty ? WFilters.defaults : WFilters.fromJson(saved);
  }

  late WFilters filters;
  Vibe? vibe = kVibes.first;
  String search = '';

  final List<Wall> items = [];
  final Set<String> _ids = {};
  bool loading = false;
  bool done = false;
  bool started = false;
  Object? error;
  int total = 0;
  List<String> relaxed = const [];

  int _page = 0;
  int _lastPage = 1;
  int _gen = 0;
  String _seed = _newSeed();
  late WFilters _effective = filters;

  static String _newSeed() {
    const a = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(6, (_) => a[r.nextInt(a.length)]).join();
  }

  String get query => search.isNotEmpty ? search : (vibe?.q ?? '');
  WTone get tone {
    final v = search.isEmpty ? (vibe?.tone ?? WTone.any) : WTone.any;
    return v.index > filters.tone.index ? v : filters.tone;
  }

  String get title => search.isNotEmpty ? (search.startsWith('id:') ? 'Tag' : '“$search”') : (vibe?.name ?? 'All');

  void setFilters(WFilters f) {
    filters = f;
    app.store.set('wall.filters', f.toJson());
    refresh();
  }

  void setVibe(Vibe? v) {
    vibe = v;
    search = '';
    refresh();
  }

  void setSearch(String q, {String? label}) {
    search = q.trim();
    tagLabel = label;
    if (search.isNotEmpty) vibe = null;
    if (search.isEmpty && vibe == null) vibe = kVibes.first;
    refresh();
  }

  /// Display name when searching by tag id.
  String? tagLabel;

  bool _vibeColor = true;
  bool _vibeSort = true;

  Map<String, String> _params(WFilters f, int page) {
    final useVibe = search.isEmpty ? vibe : null;
    final vibeSort = _vibeSort && f.sort == WFilters.defaults.sort ? useVibe?.sort : null;
    return Wallhaven.params(
      q: query,
      f: f,
      categories: useVibe?.categories,
      color: f.color ?? (_vibeColor ? useVibe?.color : null),
      sort: vibeSort ?? f.sort,
      range: vibeSort != null ? useVibe?.range : null,
      page: page,
      seed: _seed,
    );
  }

  Future<void> refresh() async {
    final gen = ++_gen;
    started = true;
    items.clear();
    _ids.clear();
    _page = 0;
    _lastPage = 1;
    total = 0;
    done = false;
    error = null;
    relaxed = const [];
    _seed = _newSeed();
    _effective = filters;
    loading = true;
    notifyListeners();
    try {
      // Find filters that return something, relaxing the strictest ones step by step.
      var f = filters;
      _vibeColor = true;
      _vibeSort = true;
      final steps = <String>[];
      var first = await Wallhaven.search(_params(f, 1));
      final ladder = <(String, bool Function())>[
        ('any color', () {
          final had = f.color != null || (_vibeColor && search.isEmpty && vibe?.color != null);
          f = f.copyWith(clearColor: true);
          _vibeColor = false;
          return had;
        }),
        ('all portrait sizes', () {
          final had = f.fit != WFit.portrait;
          f = f.copyWith(fit: WFit.portrait);
          return had;
        }),
        ('QHD+ quality', () {
          final had = f.quality == WQuality.uhd;
          if (had) f = f.copyWith(quality: WQuality.qhd);
          return had;
        }),
        ('Full HD quality', () {
          final had = f.quality == WQuality.qhd;
          if (had) f = f.copyWith(quality: WQuality.fhd);
          return had;
        }),
        ('all-time popular', () {
          final had = f.sort != WSort.popular || (search.isEmpty && vibe?.sort != null);
          f = f.copyWith(sort: WSort.popular);
          _vibeSort = false;
          return had;
        }),
      ];
      for (final (label, apply) in ladder) {
        if (first.total > 0 || gen != _gen) break;
        if (!apply()) continue;
        steps.add(label);
        first = await Wallhaven.search(_params(f, 1));
      }
      if (gen != _gen) return;
      _effective = f;
      relaxed = first.total > 0 ? steps : const [];
      total = first.total;
      _accept(first);
      if (_shown < 12 && !done) await _fill(gen, 12);
    } catch (e) {
      if (gen == _gen) error = e;
    }
    if (gen == _gen) {
      loading = false;
      notifyListeners();
    }
  }

  int _shown = 0;

  void _accept(WallPage p) {
    _page = p.page == 0 ? _page + 1 : p.page;
    _lastPage = p.lastPage;
    final t = tone;
    for (final w in p.items) {
      // Re-uploads share size and palette; show each picture once.
      final sig = '${w.w}x${w.h}:${w.colors.join()}';
      if (_ids.contains(w.id) || _ids.contains(sig) || !t.accepts(w)) continue;
      _ids
        ..add(w.id)
        ..add(sig);
      items.add(w);
    }
    _shown = items.length;
    done = _page >= _lastPage;
  }

  Future<void> _fill(int gen, int want) async {
    final start = items.length;
    var pages = 0;
    while (!done && items.length - start < want && pages < 4 && gen == _gen) {
      final p = await Wallhaven.search(_params(_effective, _page + 1));
      if (gen != _gen) return;
      _accept(p);
      pages++;
      notifyListeners();
    }
  }

  Future<void> more() async {
    if (loading || done || !started) return;
    final gen = _gen;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _fill(gen, 12);
    } catch (e) {
      if (gen == _gen) error = e;
    }
    if (gen == _gen) {
      loading = false;
      notifyListeners();
    }
  }
}

// ───────────────────────── Saved ─────────────────────────

class WallSaved {
  static const _k = 'wall.saved';
  static List<Wall> all() => app.store.list(_k).map(Wall.fromJson).toList();
  static bool has(String id) => app.store.list(_k).any((e) => e['id'] == id);

  static void toggle(Wall w) {
    final l = app.store.list(_k);
    final i = l.indexWhere((e) => e['id'] == w.id);
    if (i >= 0) {
      l.removeAt(i);
    } else {
      l.insert(0, w.toJson());
    }
    app.store.set(_k, l);
  }

  static bool get termsAccepted => app.store.flag('wall.terms');
  static void acceptTerms() => app.store.set('wall.terms', true);
}

// ───────────────────────── Files & native ─────────────────────────

class WallCancel {
  http.Client? _client;
  bool cancelled = false;
  void cancel() {
    cancelled = true;
    _client?.close();
  }
}

class WallFiles {
  static Future<Directory> _dir() async {
    final d = Directory('${(await getTemporaryDirectory()).path}/walls');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File?> cached(Wall w) async {
    final f = File('${(await _dir()).path}/${w.fileName}');
    return await f.exists() ? f : null;
  }

  /// Downloads the full-resolution file (reused from cache when present).
  static Future<File> fetch(Wall w, {ValueChanged<double>? onProgress, WallCancel? cancel}) async {
    final dir = await _dir();
    final file = File('${dir.path}/${w.fileName}');
    if (await file.exists()) return file;
    final part = File('${file.path}.part');
    final client = http.Client();
    cancel?._client = client;
    try {
      final res = await client.send(http.Request('GET', Uri.parse(w.path))..headers.addAll(_ua));
      if (res.statusCode == 429) throw WallhavenBusy();
      if (res.statusCode >= 400) throw Exception('Download failed (HTTP ${res.statusCode})');
      final totalBytes = res.contentLength ?? (w.size > 0 ? w.size : null);
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final chunk in res.stream) {
          if (cancel?.cancelled == true) throw const _Cancelled();
          sink.add(chunk);
          got += chunk.length;
          if (totalBytes != null && totalBytes > 0) onProgress?.call((got / totalBytes).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }
      await part.rename(file.path);
      unawaited(_prune(dir));
      return file;
    } catch (e) {
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> _prune(Directory dir) async {
    try {
      final files = dir.listSync().whereType<File>().where((f) => !f.path.endsWith('.part')).toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      for (final f in files.skip(14)) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

bool isCancel(Object e) => e is _Cancelled || (e is http.ClientException && e.message.contains('closed'));

class WallNative {
  static const _ch = MethodChannel('so_widget/wallpaper');

  static bool get supported => Platform.isAndroid;

  static Future<String?> save(File f, Wall w, {String credit = '', String artist = ''}) =>
      _ch.invokeMethod<String>('save', {
        'path': f.path,
        'name': w.fileName,
        'mime': w.fileType,
        'credit': credit,
        'artist': artist,
      });

  /// target: home | lock | both. ax/ay: crop alignment 0..1.
  static Future<void> set(File f, String target, {double ax = 0.5, double ay = 0.5}) =>
      _ch.invokeMethod<bool>('set', {'path': f.path, 'target': target, 'ax': ax, 'ay': ay});
}

String compactNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  return '$n';
}
