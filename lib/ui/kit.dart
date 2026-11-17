import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/style.dart';

/// Set to false in tests (no network font loading).
bool useGoogleFonts = true;

/// Font family used when [useGoogleFonts] is false.
String? fallbackFontFamily;

/// Render context handed to every widget face.
class WCtx {
  // ignore: prefer_initializing_formals
  const WCtx(this.s, this.size, {this.live = true, Size? dims}) : _dims = dims;
  final WStyle s;

  /// Layout family (small / medium / large).
  final WSize size;
  final Size? _dims;

  /// Actual canvas size. Equals the layout's base size, or is stretched to match the
  /// real home-screen cell shape (2x3, 3x2, 4x3…).
  Size get dims => _dims ?? size.logical;

  /// false when rendering a snapshot for the home screen.
  final bool live;

  WCtx withStyle(WStyle st) => WCtx(st, size, live: live, dims: _dims);

  bool get sm => size == WSize.small;
  bool get md => size == WSize.medium;
  bool get lg => size == WSize.large;

  Color get fg => s.fg;
  Color get bg => s.bg;
  Color get accent => s.accent;
  Color get dim => s.fg.withValues(alpha: 0.60);
  Color get faint => s.fg.withValues(alpha: 0.055);
  Color get line => s.fg.withValues(alpha: 0.10);
  bool get isLight => s.bg.computeLuminance() > 0.5;

  /// Accent if the style has one, otherwise a warm sun orange.
  Color get warm => s.accent == s.fg ? const Color(0xFFFF9F0A) : s.accent;

  /// Accent if the style has one, otherwise a soft green.
  Color get pos => s.accent == s.fg ? const Color(0xFF63D69A) : s.accent;
  Color get neg => const Color(0xFFFF6B5E);

  List<Shadow>? glowFor(Color c, [double k = 1]) {
    if (!s.glow || s.glowStrength <= 0) return null;
    return [
      Shadow(
        color: c.withValues(alpha: (0.18 * s.glowStrength * k).clamp(0.0, 1.0)),
        blurRadius: 2 + 8 * s.glowStrength * k,
      ),
    ];
  }

  List<BoxShadow>? boxGlow(Color c, [double k = 1]) {
    if (!s.glow || s.glowStrength <= 0) return null;
    return [
      BoxShadow(
        color: c.withValues(alpha: (0.20 * s.glowStrength * k).clamp(0.0, 1.0)),
        blurRadius: 4 + 12 * s.glowStrength * k,
        spreadRadius: 0,
      ),
    ];
  }

  TextStyle t(
    double size, {
    FontWeight w = FontWeight.w500,
    Color? c,
    bool dim = false,
    String? font,
    double? h,
    double? ls,
    bool? glow,
    TextDecoration? deco,
  }) {
    final color = c ?? (dim ? this.dim : fg);
    final wi = (FontWeight.values.indexOf(w) + s.weight).clamp(0, FontWeight.values.length - 1);
    final base = TextStyle(
      fontSize: size * s.textScale,
      fontWeight: FontWeight.values[wi],
      color: color,
      height: h ?? 1.1,
      letterSpacing: ls ?? (size > 22 ? -size * 0.04 : 0),
      shadows: (glow ?? s.textGlow) && !dim
          ? glowFor(color, size > 30 ? 1 : 0.6)
          : null,
      fontFeatures: const [FontFeature.tabularFigures()],
      decoration: deco,
      decorationColor: color,
    );
    if (!useGoogleFonts) return base.copyWith(fontFamily: fallbackFontFamily);
    try {
      return GoogleFonts.getFont(font ?? s.font, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  TextStyle script(double size, {Color? c}) =>
      t(size, w: FontWeight.w400, font: s.scriptFont, c: c, ls: 0, h: 1.15);

  TextStyle mono(double size, {Color? c, bool dim = true}) => t(
    size,
    w: FontWeight.w500,
    font: 'JetBrains Mono',
    c: c,
    dim: dim,
    ls: 0.4,
  );
}

/// The squircle canvas every widget is drawn on.
class WShell extends StatelessWidget {
  const WShell({
    super.key,
    required this.c,
    required this.child,
    this.padding,
    this.background,
    this.bg,
  });

  final WCtx c;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Widget? background;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final sz = c.dims;
    final base = bg ?? c.bg;
    final r = BorderRadius.circular(math.min(c.s.radius, sz.shortestSide / 2));
    final hsl = HSLColor.fromColor(base);
    final top = c.s.sheen
        ? hsl
              .withLightness(
                (hsl.lightness + (c.isLight ? 0.02 : 0.035)).clamp(0.0, 1.0),
              )
              .toColor()
        : base;
    final a = c.s.bgOpacity.clamp(0.0, 1.0);
    final showBorder = c.s.border && c.s.borderWidth > 0 && c.s.borderOpacity > 0;
    return SizedBox(
      width: sz.width,
      height: sz.height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: r,
            side: showBorder
                ? BorderSide(
                    color: c.fg.withValues(alpha: c.s.borderOpacity),
                    width: c.s.borderWidth,
                    strokeAlign: BorderSide.strokeAlignInside,
                  )
                : BorderSide.none,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [top.withValues(alpha: a), base.withValues(alpha: a)],
          ),
        ),
        child: ClipRSuperellipse(
          borderRadius: r,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ?background,
              Padding(
                padding:
                    padding ??
                    EdgeInsets.all((c.sm ? 16 : 18) - (c.s.compact ? 4 : 0)),
                child: MediaQuery.withNoTextScaling(
                  child: DefaultTextStyle(style: c.t(14), child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scales a child down to fit, aligned left by default.
Widget fit(Widget w, {Alignment a = Alignment.centerLeft}) =>
    FittedBox(fit: BoxFit.scaleDown, alignment: a, child: w);

/// Small dim header: icon + label (e.g. "⚡ Charging...").
class WHeader extends StatelessWidget {
  const WHeader(
    this.c,
    this.icon,
    this.label, {
    super.key,
    this.trailing,
    this.size,
  });
  final WCtx c;
  final IconData? icon;
  final String label;
  final String? trailing;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final fs = size ?? (c.sm ? 12.0 : 13.0);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: fs + 2, color: c.dim),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: c.t(fs, dim: true),
          ),
        ),
        if (trailing != null) Text(trailing!, style: c.t(fs - 1, dim: true)),
      ],
    );
  }
}

/// Glowing horizontal bar (charging style).
class GlowBar extends StatelessWidget {
  const GlowBar(
    this.c,
    this.value, {
    super.key,
    this.height = 14,
    this.color,
    this.tick = false,
  });
  final WCtx c;
  final double value;
  final double height;
  final Color? color;
  final bool tick;

  @override
  Widget build(BuildContext context) {
    final col = color ?? c.accent;
    final rad = BorderRadius.circular(height / 2);
    return LayoutBuilder(
      builder: (context, bc) {
        final w = bc.maxWidth;
        final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
        final fill = v == 0 ? 0.0 : math.max(w * v, math.min(height, w));
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.faint, borderRadius: rad),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: fill,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [col, col.withValues(alpha: 0.85)],
                    ),
                    borderRadius: rad,
                    boxShadow: c.boxGlow(col, height > 30 ? 1 : 0.5),
                  ),
                ),
              ),
              if (tick && fill > 40)
                Positioned(
                  left: fill * 0.82,
                  top: height * 0.3,
                  bottom: height * 0.3,
                  width: 1.2,
                  child: ColoredBox(color: c.bg.withValues(alpha: 0.25)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Concentric progress rings.
class Rings extends StatelessWidget {
  const Rings(
    this.c,
    this.values, {
    super.key,
    this.colors,
    this.stroke = 10,
    this.gap = 3,
    this.child,
  });
  final WCtx c;
  final List<double> values;
  final List<Color>? colors;
  final double stroke;
  final double gap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _RingPainter(
          values,
          colors ?? List.filled(values.length, c.accent),
          stroke,
          gap,
          c.faint,
          c.s.glow ? c.s.glowStrength : 0,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
    this.values,
    this.colors,
    this.stroke,
    this.gap,
    this.track,
    this.glow,
  );
  final List<double> values;
  final List<Color> colors;
  final double stroke, gap, glow;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < values.length; i++) {
      final r = size.shortestSide / 2 - stroke / 2 - i * (stroke + gap);
      if (r <= 0) break;
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i].withValues(alpha: 0.14),
      );
      final v = values[i].isNaN ? 0.0 : values[i].clamp(0.0, 1.0);
      if (v <= 0) continue;
      final sweep = 2 * math.pi * v;
      if (glow > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = colors[i].withValues(alpha: 0.22 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 4 * glow),
        );
      }
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.values != values || o.colors != colors || o.glow != glow;
}

/// Sparkline with soft fill.
class Spark extends StatelessWidget {
  const Spark(
    this.c,
    this.values, {
    super.key,
    this.color,
    this.fill = true,
    this.stroke = 2,
  });
  final WCtx c;
  final List<double> values;
  final Color? color;
  final bool fill;
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _SparkPainter(
      values,
      color ?? c.fg,
      fill,
      stroke,
      c.s.glow ? c.s.glowStrength : 0,
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color, this.fill, this.stroke, this.glow);
  final List<double> v;
  final Color color;
  final bool fill;
  final double stroke, glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final mn = v.reduce(math.min), mx = v.reduce(math.max);
    final span = (mx - mn) == 0 ? 1 : (mx - mn);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / (v.length - 1);
      final y =
          size.height -
          (v[i] - mn) / span * size.height * 0.9 -
          size.height * 0.05;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    if (glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 1
          ..color = color.withValues(alpha: 0.18 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 5 * glow),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter o) => o.v != v || o.color != color;
}

/// Inner rounded panel (Bogotá-style tiles).
class Tile extends StatelessWidget {
  const Tile(
    this.c, {
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.border = true,
  });
  final WCtx c;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final bool border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: color ?? c.faint,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(math.max(12, c.s.radius * 0.52)),
        side: border ? BorderSide(color: c.line, width: 0.6) : BorderSide.none,
      ),
    ),
    child: Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
  );
}

/// Analog dial with glowing accent hands.
class Dial extends StatelessWidget {
  const Dial(this.c, this.time, {super.key, this.label, this.hand});
  final WCtx c;
  final DateTime time;
  final String? label;
  final Color? hand;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: CustomPaint(
      painter: _DialPainter(
        time,
        c.fg,
        hand ?? c.pos,
        c.s.glow ? c.s.glowStrength : 0,
        c.faint,
      ),
      child: label == null
          ? null
          : Align(
              alignment: const Alignment(0, 0.42),
              child: fit(
                Text(label!, style: c.t(9, dim: true, ls: 0.6)),
                a: Alignment.center,
              ),
            ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.t, this.fg, this.hand, this.glow, this.face);
  final DateTime t;
  final Color fg, hand, face;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = face);
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = fg.withValues(alpha: 0.12),
    );
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final major = i % 5 == 0;
      final len = major ? r * 0.12 : r * 0.05;
      final p1 = c + Offset(math.sin(a), -math.cos(a)) * (r * 0.9);
      final p2 = c + Offset(math.sin(a), -math.cos(a)) * (r * 0.9 - len);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = major ? 1.6 : 0.8
          ..color = fg.withValues(alpha: major ? 0.8 : 0.35),
      );
    }
    void handLine(double angle, double len, double w) {
      final end = c + Offset(math.sin(angle), -math.cos(angle)) * len;
      if (glow > 0) {
        canvas.drawLine(
          c,
          end,
          Paint()
            ..strokeWidth = w + 2
            ..strokeCap = StrokeCap.round
            ..color = hand.withValues(alpha: 0.22 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 4 * glow),
        );
      }
      canvas.drawLine(
        c,
        end,
        Paint()
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..color = hand,
      );
    }

    final m = t.minute + t.second / 60;
    final h = (t.hour % 12) + m / 60;
    handLine(h * math.pi / 6, r * 0.5, math.max(2.5, r * 0.07));
    handLine(m * math.pi / 30, r * 0.76, math.max(2, r * 0.05));
    canvas.drawCircle(c, math.max(2.5, r * 0.06), Paint()..color = fg);
  }

  @override
  bool shouldRepaint(covariant _DialPainter o) => o.t != t || o.hand != hand;
}

/// Equirectangular graticule with plotted points (ISS, earthquakes).
class MapGrid extends StatelessWidget {
  const MapGrid(
    this.c, {
    super.key,
    required this.points,
    this.trail = const [],
  });
  final WCtx c;

  /// (lat, lon, size 0..1)
  final List<(double, double, double)> points;
  final List<(double, double)> trail;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _MapPainter(
      points,
      trail,
      c.fg,
      c.warm,
      c.s.glow ? c.s.glowStrength : 0,
    ),
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.points, this.trail, this.fg, this.hot, this.glow);
  final List<(double, double, double)> points;
  final List<(double, double)> trail;
  final Color fg, hot;
  final double glow;

  Offset _p(Size s, double lat, double lon) =>
      Offset((lon + 180) / 360 * s.width, (90 - lat) / 180 * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = fg.withValues(alpha: 0.16);
    const step = 10.0;
    for (var lat = -80.0; lat <= 80; lat += step) {
      for (var lon = -175.0; lon <= 175; lon += step) {
        canvas.drawCircle(_p(size, lat, lon), 0.9, dot);
      }
    }
    final eq = Paint()
      ..color = fg.withValues(alpha: 0.22)
      ..strokeWidth = 0.8;
    canvas.drawLine(_p(size, 0, -180), _p(size, 0, 180), eq);
    if (trail.length > 1) {
      final path = Path();
      for (var i = 0; i < trail.length; i++) {
        final o = _p(size, trail[i].$1, trail[i].$2);
        if (i == 0 || (trail[i].$2 - trail[i - 1].$2).abs() > 180) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = hot.withValues(alpha: 0.55),
      );
    }
    for (final p in points) {
      final o = _p(size, p.$1, p.$2);
      final r = 2.5 + p.$3 * 7;
      if (glow > 0) {
        canvas.drawCircle(
          o,
          r * 1.8,
          Paint()
            ..color = hot.withValues(alpha: 0.45 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 6 * glow),
        );
      }
      canvas.drawCircle(o, r, Paint()..color = hot);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter o) => true;
}

/// Shown when a widget has no data yet.
class WEmpty extends StatelessWidget {
  const WEmpty(this.c, this.icon, this.text, {super.key, this.title});
  final WCtx c;
  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) => WShell(
    c: c,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) WHeader(c, icon, title!),
        const Spacer(),
        Icon(icon, size: c.sm ? 28 : 34, color: c.fg, shadows: c.glowFor(c.fg)),
        const SizedBox(height: 8),
        Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: c.t(c.sm ? 13 : 15, dim: true, h: 1.25),
        ),
      ],
    ),
  );
}

const kMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const kDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String dayShort(DateTime d) => kDays[d.weekday - 1].substring(0, 3);
String monShort(DateTime d) => kMonths[d.month - 1].substring(0, 3);

String hm(DateTime t, bool h24, {bool ampm = false}) {
  final m = t.minute.toString().padLeft(2, '0');
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:$m';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return ampm ? '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}' : '$h:$m';
}

String dur(Duration d, {bool short = false}) {
  final neg = d.isNegative;
  d = d.abs();
  final h = d.inHours, m = d.inMinutes % 60;
  String s;
  if (d.inDays >= 2) {
    s = '${d.inDays} days';
  } else if (h > 0) {
    s = short ? '${h}h ${m}m' : '$h hr${h > 1 ? 's' : ''} $m min';
  } else {
    s = '${d.inMinutes} min';
  }
  return neg ? '-$s' : s;
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}

String groupNum(num v, {int decimals = 0}) {
  final s = v.toStringAsFixed(decimals);
  final parts = s.split('.');
  final buf = StringBuffer();
  final digits = parts[0].replaceAll('-', '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${s.startsWith('-') ? '-' : ''}$buf${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String money(num v) {
  if (v >= 1000) return '\$${groupNum(v, decimals: 0).replaceAll(' ', ',')}';
  if (v >= 1) return '\$${v.toStringAsFixed(2)}';
  return '\$${v.toStringAsFixed(4)}';
}

String pct(num v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

/// Used by Cupertino imports so the analyzer keeps both available to faces.
const kChevron = CupertinoIcons.chevron_right;
