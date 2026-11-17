import 'package:material_ui/material_ui.dart';

/// The three canvas sizes every So Widget can render at.
enum WSize { small, medium, large }

extension WSizeX on WSize {
  Size get logical => switch (this) {
    WSize.small => const Size(170, 170),
    WSize.medium => const Size(364, 170),
    WSize.large => const Size(364, 382),
  };

  String get label => switch (this) {
    WSize.small => 'Small',
    WSize.medium => 'Medium',
    WSize.large => 'Large',
  };
}

/// Visual style of a widget. One global style, optionally overridden per widget.
@immutable
class WStyle {
  const WStyle({
    required this.bg,
    required this.fg,
    required this.accent,
    this.glow = true,
    this.glowStrength = 0.22,
    this.font = 'Inter',
    this.scriptFont = 'Inter',
    this.radius = 32,
    this.sheen = true,
    this.textScale = 1,
    this.compact = false,
    this.border = true,
    this.textGlow = false,
    this.bgOpacity = 1,
    this.borderWidth = 1,
    this.borderOpacity = 0.12,
    this.weight = 0,
  });

  final Color bg;
  final Color fg;
  final Color accent;
  final bool glow;
  final double glowStrength;
  final String font;
  final String scriptFont;
  final double radius;
  final bool sheen;
  final double textScale;
  final bool compact;
  final bool border;
  final bool textGlow;

  /// 0.25..1 — below 1 the wallpaper shows through (glass look).
  final double bgOpacity;

  /// Outline drawn around every widget so all widgets share one line.
  final double borderWidth;
  final double borderOpacity;

  /// Font weight shift: -2 (light) .. +2 (heavy).
  final int weight;

  bool sameAs(WStyle other) {
    final values = other.toJson();
    return toJson().entries.every((e) => values[e.key] == e.value);
  }

  WStyle copyWith({
    Color? bg,
    Color? fg,
    Color? accent,
    bool? glow,
    double? glowStrength,
    String? font,
    String? scriptFont,
    double? radius,
    bool? sheen,
    double? textScale,
    bool? compact,
    bool? border,
    bool? textGlow,
    double? bgOpacity,
    double? borderWidth,
    double? borderOpacity,
    int? weight,
  }) => WStyle(
    bg: bg ?? this.bg,
    fg: fg ?? this.fg,
    accent: accent ?? this.accent,
    glow: glow ?? this.glow,
    glowStrength: glowStrength ?? this.glowStrength,
    font: font ?? this.font,
    scriptFont: scriptFont ?? this.scriptFont,
    radius: radius ?? this.radius,
    sheen: sheen ?? this.sheen,
    textScale: textScale ?? this.textScale,
    compact: compact ?? this.compact,
    border: border ?? this.border,
    textGlow: textGlow ?? this.textGlow,
    bgOpacity: bgOpacity ?? this.bgOpacity,
    borderWidth: borderWidth ?? this.borderWidth,
    borderOpacity: borderOpacity ?? this.borderOpacity,
    weight: weight ?? this.weight,
  );

  Map<String, dynamic> toJson() => {
    'bg': bg.toARGB32(),
    'fg': fg.toARGB32(),
    'accent': accent.toARGB32(),
    'glow': glow,
    'glowStrength': glowStrength,
    'font': font,
    'scriptFont': scriptFont,
    'radius': radius,
    'sheen': sheen,
    'textScale': textScale,
    'compact': compact,
    'border': border,
    'textGlow': textGlow,
    'bgOpacity': bgOpacity,
    'borderWidth': borderWidth,
    'borderOpacity': borderOpacity,
    'weight': weight,
  };

  factory WStyle.fromJson(Map<String, dynamic> j) => WStyle(
    bg: Color((j['bg'] as num?)?.toInt() ?? 0xFF161618),
    fg: Color((j['fg'] as num?)?.toInt() ?? 0xFFF5F5F7),
    accent: Color((j['accent'] as num?)?.toInt() ?? 0xFFF5F5F7),
    glow: j['glow'] as bool? ?? true,
    glowStrength: (j['glowStrength'] as num?)?.toDouble() ?? 0.22,
    font: kFonts.contains(j['font']) ? j['font'] as String : 'Inter',
    scriptFont: kScriptFonts.contains(j['scriptFont'])
        ? j['scriptFont'] as String
        : 'Inter',
    radius: (j['radius'] as num?)?.toDouble() ?? 32,
    sheen: j['sheen'] as bool? ?? true,
    textScale: ((j['textScale'] as num?)?.toDouble() ?? 1).clamp(0.8, 1.15),
    compact: j['compact'] as bool? ?? false,
    border: j['border'] as bool? ?? true,
    textGlow: j['textGlow'] as bool? ?? false,
    bgOpacity: ((j['bgOpacity'] as num?)?.toDouble() ?? 1).clamp(0.25, 1.0),
    borderWidth: ((j['borderWidth'] as num?)?.toDouble() ?? 1).clamp(0.0, 3.0),
    borderOpacity: ((j['borderOpacity'] as num?)?.toDouble() ?? 0.12).clamp(0.0, 1.0),
    weight: ((j['weight'] as num?)?.toInt() ?? 0).clamp(-2, 2),
  );

  static const graphite = WStyle(
    bg: Color(0xFF161618),
    fg: Color(0xFFF5F5F7),
    accent: Color(0xFFF5F5F7),
  );
}

/// iOS-like fonts first (SF Pro has no free web version; these are the closest).
const kFonts = [
  'Inter',
  'Geist',
  'Inter Tight',
  'Figtree',
  'Onest',
  'Instrument Sans',
  'Hanken Grotesk',
  'Albert Sans',
  'Public Sans',
  'Nunito',
  'M PLUS Rounded 1c',
  'Newsreader',
  'Geist Mono',
  'Manrope',
  'DM Sans',
  'Outfit',
  'Plus Jakarta Sans',
  'Space Grotesk',
  'Sora',
  'JetBrains Mono',
];

/// Which Apple font each choice resembles.
const kFontNotes = {
  'Inter': 'SF Pro Text',
  'Geist': 'SF Pro Display',
  'Inter Tight': 'SF Pro · tight',
  'Figtree': 'SF Pro · soft',
  'Onest': 'SF Pro · round',
  'Instrument Sans': 'SF Compact',
  'Hanken Grotesk': 'SF Pro · light',
  'Albert Sans': 'SF Pro · wide',
  'Public Sans': 'SF Pro · neutral',
  'Nunito': 'SF Rounded',
  'M PLUS Rounded 1c': 'SF Rounded · bold',
  'Newsreader': 'New York',
  'Geist Mono': 'SF Mono',
};

const kScriptFonts = [
  'Pinyon Script',
  'Great Vibes',
  'Playfair Display',
  'Italianno',
  ...kFonts,
];

class StylePreset {
  const StylePreset(this.name, this.style);
  final String name;
  final WStyle style;
}

const kPresets = [
  StylePreset('Graphite', WStyle.graphite),
  StylePreset(
    'Midnight',
    WStyle(
      bg: Color(0xFF000000),
      fg: Color(0xFFFFFFFF),
      accent: Color(0xFF7CF29A),
      glowStrength: 0.75,
    ),
  ),
  StylePreset(
    'Paper',
    WStyle(
      bg: Color(0xFFF4F4F6),
      fg: Color(0xFF111111),
      accent: Color(0xFFFF9500),
      glow: false,
      font: 'Inter Tight',
    ),
  ),
  StylePreset(
    'Mist',
    WStyle(
      bg: Color(0xFFA9C3D0),
      fg: Color(0xFF0B0B0B),
      accent: Color(0xFF0B0B0B),
      glow: false,
      font: 'Manrope',
      radius: 30,
    ),
  ),
  StylePreset(
    'Ember',
    WStyle(
      bg: Color(0xFF1A110E),
      fg: Color(0xFFFFE8D6),
      accent: Color(0xFFFF8A3D),
      glowStrength: 0.7,
    ),
  ),
  StylePreset(
    'Ocean',
    WStyle(
      bg: Color(0xFF0A1626),
      fg: Color(0xFFE6F0FF),
      accent: Color(0xFF4DA3FF),
      font: 'DM Sans',
    ),
  ),
  StylePreset(
    'Rosé',
    WStyle(
      bg: Color(0xFF1C1216),
      fg: Color(0xFFFFE4EC),
      accent: Color(0xFFFF6B9A),
      font: 'Outfit',
    ),
  ),
  StylePreset(
    'Mono',
    WStyle(
      bg: Color(0xFF0E0E0E),
      fg: Color(0xFFEDEDED),
      accent: Color(0xFFEDEDED),
      glow: false,
      font: 'JetBrains Mono',
      radius: 26,
      sheen: false,
    ),
  ),
  StylePreset('Amethyst', WStyle(bg: Color(0xFF191425), fg: Color(0xFFF0E9FF),
      accent: Color(0xFFB99AFF), font: 'Sora')),
  StylePreset('Sand', WStyle(bg: Color(0xFF211D18), fg: Color(0xFFF8F0E2),
      accent: Color(0xFFD9B77E), font: 'Manrope', glow: false)),
];

/// Retain a theme's light/dark character while tinting its surface.
WStyle tintTheme(WStyle current, WStyle base, Color main) {
  final hue = HSLColor.fromColor(main);
  final surface = HSLColor.fromColor(base.bg);
  return current.copyWith(
    accent: main,
    bg: HSLColor.fromAHSL(1, hue.hue, hue.saturation * 0.28, surface.lightness).toColor(),
  );
}

const kSwatches = [
  Color(0xFF000000),
  Color(0xFF0E0E0E),
  Color(0xFF141414),
  Color(0xFF1C1C1E),
  Color(0xFF2C2C2E),
  Color(0xFF3A3A3C),
  Color(0xFF8E8E93),
  Color(0xFFD1D1D6),
  Color(0xFFF4F4F6),
  Color(0xFFFFFFFF),
  Color(0xFFFF453A),
  Color(0xFFFF9F0A),
  Color(0xFFFFD60A),
  Color(0xFF7CF29A),
  Color(0xFF30D158),
  Color(0xFF64D2FF),
  Color(0xFFA9C3D0),
  Color(0xFF0A84FF),
  Color(0xFF5E5CE6),
  Color(0xFFBF5AF2),
  Color(0xFFFF6B9A),
  Color(0xFF1A110E),
  Color(0xFF0A1626),
  Color(0xFFFFE8D6),
];

String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? parseHex(String s) {
  var h = s.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((e) => '$e$e').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}
