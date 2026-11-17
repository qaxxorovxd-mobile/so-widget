import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../core/media.dart';
import '../core/registry.dart';
import '../core/style.dart';
import '../ui/kit.dart';
import '../ui/media_controls.dart';

/// Media widgets are drawn natively on Android (SoNowPlaying.kt) so they update live on the
/// home screen. In the app we show the very same native drawing as a preview image.
final mediaWidgets = <WDef>[
  _def(51, 'm_vinyl', 'Vinyl', 'A record slides out of its sleeve. Waveform progress and pill controls.',
      CupertinoIcons.music_albums_fill),
  _def(52, 'm_cover', 'Cover', 'Full-bleed album art with glass controls.', CupertinoIcons.photo_fill_on_rectangle_fill,
      preferred: WSize.large),
  _def(53, 'm_wave', 'Wave', 'The song’s waveform lights up as it plays.', CupertinoIcons.waveform,
      preferred: WSize.medium),
  _def(54, 'm_disc', 'Disc', 'Round artwork with a glowing progress ring. Tap the disc to play or pause.',
      CupertinoIcons.circle_grid_3x3_fill),
  _def(55, 'm_type', 'Lyric Type', 'Editorial typography: now playing, title, artist and time.', CupertinoIcons.textformat,
      preferred: WSize.medium),
  _def(56, 'm_capsule', 'Capsule', 'Blurred artwork with a floating glass player capsule.', CupertinoIcons.capsule_fill,
      preferred: WSize.medium),
];

WDef _def(int no, String id, String name, String desc, IconData icon, {WSize preferred = WSize.small}) => WDef(
      no: no,
      id: id,
      name: name,
      desc: '$desc Works with Spotify, YouTube Music and any player.',
      cat: WCat.media,
      icon: icon,
      preferred: preferred,
      face: (c) => MediaFace(id, c, fallback: (c) => _fallback(c, name, icon)),
      editor: (ctx) => const MediaControls(),
    );

/// Simple Flutter face used where the native renderer is not available (iOS, tests, first frame).
Widget _fallback(WCtx c, String name, IconData icon) {
  final m = media.value;
  return WShell(
    c: c,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, icon, name),
      const Spacer(),
      Icon(CupertinoIcons.music_note_2, size: c.sm ? 28 : 34, color: c.fg, shadows: c.glowFor(c.fg)),
      const SizedBox(height: 8),
      Text(m.hasTrack ? m.title : 'Now Playing',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 16 : 19)),
      Text(m.hasTrack ? m.artist : 'Live media from any app',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 12 : 14, dim: true)),
    ]),
  );
}

/// Caches native preview bitmaps keyed by widget, size, style and track state.
class MediaPreviews extends ChangeNotifier {
  static const _ch = MethodChannel('so_widget/native');
  final Map<String, ui.Image> _cache = {};
  final Map<String, ui.Image> _last = {};
  final Set<String> _loading = {};
  final List<String> _order = [];
  bool _unavailable = false;

  ui.Image? get(String id, Size size, WStyle style) {
    if (_unavailable || !Platform.isAndroid) return null;
    final m = media.value;
    final styleKey = jsonEncode(style.toJson());
    final base = '$id|${size.width.round()}x${size.height.round()}|$styleKey';
    final bucket = m.playing ? m.position ~/ 2000 : 0;
    final key = '$base|${m.allowed}|${m.title}|${m.artist}|${m.playing}|$bucket|${media.artwork?.hashCode}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_loading.add(key)) _load(key, base, id, size, styleKey);
    return _last[base];
  }

  Future<void> _load(String key, String base, String id, Size size, String style) async {
    try {
      final bytes = await _ch.invokeMethod<Uint8List>('mediaPreview', {
        'id': id,
        'w': size.width.round(),
        'h': size.height.round(),
        'style': style,
      });
      if (bytes == null) return;
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      _cache[key] = img;
      _last[base] = img;
      _order.add(key);
      while (_order.length > 40) {
        _cache.remove(_order.removeAt(0));
      }
      notifyListeners();
    } on MissingPluginException {
      _unavailable = true;
    } catch (_) {
      // Keep showing the last image or the fallback.
    } finally {
      _loading.remove(key);
    }
  }
}

final mediaPreviews = MediaPreviews();

class MediaFace extends StatelessWidget {
  const MediaFace(this.id, this.c, {super.key, required this.fallback});
  final String id;
  final WCtx c;
  final Widget Function(WCtx c) fallback;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([media, mediaPreviews]),
        builder: (context, _) {
          final img = mediaPreviews.get(id, c.dims, c.s);
          if (img == null) return fallback(c);
          final sz = c.dims;
          return SizedBox(
            width: sz.width,
            height: sz.height,
            child: RawImage(image: img, width: sz.width, height: sz.height, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
          );
        },
      );
}

// ───────────────────────── One-row glances ─────────────────────────

Glance mediaGlance(WCtx c) {
  final m = media.value;
  if (!m.hasTrack) {
    return Glance(m.allowed ? 'Nothing playing' : 'Media access needed',
        label: m.allowed ? 'Play music in any app' : 'Enable it in So Widget', icon: CupertinoIcons.music_note_2);
  }
  return Glance(m.title, label: m.artist, icon: m.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
      progress: m.duration > 0 ? m.progress : null);
}

final mediaGlances = <String, Glance Function(WCtx)>{
  for (final w in mediaWidgets) w.id: mediaGlance,
};