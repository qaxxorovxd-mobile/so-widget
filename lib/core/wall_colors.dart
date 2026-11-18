import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'state.dart';
import 'style.dart';

/// A widget color set picked to match the current wallpaper.
@immutable
class WallSuggestion {
  const WallSuggestion(this.name, this.bg, this.fg, this.accent);
  final String name;
  final Color bg;
  final Color fg;
  final Color accent;

  /// Only colors change: text size, outline, corners and every other personal setting stay.
  WStyle applyTo(WStyle s) => s.copyWith(bg: bg, fg: fg, accent: accent);

  bool matches(WStyle s) =>
      s.bg.toARGB32() == bg.toARGB32() &&
      s.fg.toARGB32() == fg.toARGB32() &&
      s.accent.toARGB32() == accent.toARGB32();
}

Color _hsl(double h, double s, double l) =>
    HSLColor.fromAHSL(1, h % 360, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0)).toColor();

/// Builds four harmonious widget palettes from the wallpaper's main colors.
List<WallSuggestion> suggestFrom(List<Color> colors, {bool lightWallpaper = false}) {
  if (colors.isEmpty) return const [];
  final hsl = [for (final c in colors) HSLColor.fromColor(c)];
  final base = hsl.first;
  // Most vivid color that is neither near-black nor near-white.
  double vividness(HSLColor c) => c.saturation * (1 - (c.lightness - 0.5).abs() * 1.6);
  final ranked = [...hsl]..sort((a, b) => vividness(b).compareTo(vividness(a)));
  final vivid = ranked.first;
  final colorful = vivid.saturation > 0.14 && vividness(vivid) > 0.06;
  final second = ranked.length > 1 && (ranked[1].hue - vivid.hue).abs() > 25 && ranked[1].saturation > 0.14
      ? ranked[1]
      : HSLColor.fromAHSL(1, (vivid.hue + 32) % 360, vivid.saturation, vivid.lightness);
  final baseHue = base.saturation > 0.08 ? base.hue : vivid.hue;
  final baseSat = base.saturation > 0.08 ? base.saturation : (colorful ? vivid.saturation * 0.5 : 0.0);

  Color bright(HSLColor c) => colorful
      ? _hsl(c.hue, max(c.saturation, 0.55), 0.66)
      : const Color(0xFFF5F5F7);
  Color deep(HSLColor c) => colorful ? _hsl(c.hue, max(c.saturation, 0.6), 0.4) : const Color(0xFF1C1C1E);

  final tinted = WallSuggestion(
    'Tinted',
    _hsl(baseHue, baseSat * 0.35, 0.1),
    _hsl(baseHue, baseSat * 0.2, 0.95),
    bright(vivid),
  );
  final rich = WallSuggestion(
    'Rich',
    _hsl(baseHue, min(baseSat, 0.65) * 0.75, 0.2),
    _hsl(baseHue, 0.12, 0.97),
    bright(second),
  );
  final night = WallSuggestion('Night', const Color(0xFF000000), const Color(0xFFF5F5F7), bright(vivid));
  final light = WallSuggestion(
    'Light',
    _hsl(baseHue, baseSat * 0.3, 0.94),
    _hsl(baseHue, baseSat * 0.25, 0.1),
    deep(vivid),
  );
  return lightWallpaper ? [light, tinted, rich, night] : [tinted, rich, night, light];
}

/// Tracks the home-screen wallpaper's colors and remembers which ones the user already saw.
class WallColors extends ChangeNotifier {
  static const _ch = MethodChannel('so_widget/wallpaper');
  bool _listening = false;

  List<Color> colors = const [];
  bool lightWallpaper = false;

  String get signature => colors.map((c) => c.toARGB32().toRadixString(16)).join(',');

  /// True when the wallpaper changed since the user last picked or dismissed a suggestion.
  bool get isNew => colors.isNotEmpty && app.store.str('wall.seenColors') != signature;

  List<WallSuggestion> get suggestions => suggestFrom(colors, lightWallpaper: lightWallpaper);

  void markSeen() {
    if (colors.isEmpty) return;
    app.store.set('wall.seenColors', signature);
    notifyListeners();
  }

  /// Fallback for phones without WallpaperColors: the palette of the last wallpaper set from So Widget.
  void rememberSet(List<Color> palette) {
    app.store.set('wall.lastColors', [for (final c in palette.take(3)) c.toARGB32()]);
    refresh();
  }

  Future<void> refresh() async {
    if (!_listening && !kIsWeb && Platform.isAndroid) {
      _listening = true;
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'colorsChanged') refresh();
        return null;
      });
    }
    var next = <Color>[];
    var light = false;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final r = await _ch.invokeMapMethod<String, Object?>('colors');
        if (r != null) {
          next = [for (final v in (r['colors'] as List? ?? const [])) Color((v as num).toInt() | 0xFF000000)];
          light = r['darkText'] == true;
        }
      }
    } catch (_) {}
    if (next.isEmpty) {
      final saved = app.store.raw('wall.lastColors');
      if (saved is List) next = [for (final v in saved) if (v is num) Color(v.toInt() | 0xFF000000)];
    }
    if (next.isNotEmpty && !light) {
      light = next.first.computeLuminance() > 0.5;
    }
    final changed = next.length != colors.length ||
        [for (var i = 0; i < next.length; i++) next[i].toARGB32() != colors[i].toARGB32()].any((x) => x) ||
        light != lightWallpaper;
    if (!changed) return;
    colors = next;
    lightWallpaper = light;
    notifyListeners();
  }
}

final wallColors = WallColors();
