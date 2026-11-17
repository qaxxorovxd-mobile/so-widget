import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../ui/kit.dart';
import '../widgets/creative.dart';
import '../widgets/digital.dart';
import '../widgets/essential.dart';
import '../widgets/lifestyle.dart';
import '../widgets/media.dart';
import '../widgets/productivity.dart';
import 'state.dart';
import 'style.dart';

enum WCat {
  essential('Essential', 'Everyday glanceables'),
  media('Media', 'Live music from any app'),
  productivity('Productivity', 'Get things done'),
  digital('Digital Life', 'Internet & tech'),
  lifestyle('Lifestyle', 'Personal rhythm'),
  creative('Creative & Smart', 'Unique & playful');

  const WCat(this.label, this.tagline);
  final String label;
  final String tagline;
}

class WDef {
  const WDef({
    required this.no,
    required this.id,
    required this.name,
    required this.desc,
    required this.cat,
    required this.icon,
    required this.face,
    this.editor,
    this.preferred = WSize.small,
  });

  final int no;
  final String id;
  final String name;
  final String desc;
  final WCat cat;
  final IconData icon;
  final Widget Function(WCtx c) face;
  final Widget Function(BuildContext context)? editor;
  final WSize preferred;

  String get number => no.toString().padLeft(2, '0');
}

final List<WDef> allWidgets = [
  ...essentialWidgets,
  ...productivityWidgets,
  ...digitalWidgets,
  ...lifestyleWidgets,
  ...creativeWidgets,
  ...mediaWidgets,
]..sort((a, b) => a.no.compareTo(b.no));

final Map<String, WDef> widgetById = {for (final w in allWidgets) w.id: w};

void seedAll(Store s) {
  seedEssential(s);
  seedProductivity(s);
  seedDigital(s);
  seedLifestyle(s);
  seedCreative(s);
}

/// One-line summary used when a widget is resized to a single row (2x1, 3x1, 4x1…).
class Glance {
  const Glance(this.value, {this.label = '', this.icon, this.progress, this.color, this.trailing});
  final String value;
  final String label;
  final IconData? icon;
  final double? progress;
  final Color? color;
  final String? trailing;
}

final Map<String, Glance Function(WCtx c)> glances = {
  ...essentialGlances,
  ...productivityGlances,
  ...digitalGlances,
  ...lifestyleGlances,
  ...creativeGlances,
  ...mediaGlances,
};

/// Widgets whose face draws itself natively at any size (live media).
bool isAdaptive(String id) => id == 'nowplaying' || id.startsWith('m_');

/// How a widget is laid out for a real home-screen size (in dp).
class RenderPlan {
  const RenderPlan(this.size, this.logical, {this.strip = false});

  /// Layout family the face uses.
  final WSize size;

  /// Logical canvas, same aspect ratio as the real widget.
  final Size logical;

  /// One-row widget: shows the [Glance] layout.
  final bool strip;

  @override
  String toString() => '${strip ? 'strip' : size.name} ${logical.width.round()}x${logical.height.round()}';
}

RenderPlan planFor(double w, double h) {
  w = w < 40 ? 40 : w;
  h = h < 40 ? 40 : h;
  final a = w / h;
  if (h < 118) {
    const base = 76.0;
    return RenderPlan(WSize.small, Size(a >= 1 ? base * a : base, a >= 1 ? base : base / a), strip: true);
  }
  if (a >= 1.25 && w >= 290) {
    const wide = 364 / 170;
    return a >= wide
        ? RenderPlan(WSize.medium, Size(170 * a, 170))
        : RenderPlan(WSize.medium, Size(364, 364 / a));
  }
  if ((w < h ? w : h) >= 250) {
    const tall = 364 / 382;
    return a >= tall
        ? RenderPlan(WSize.large, Size(382 * a, 382))
        : RenderPlan(WSize.large, Size(364, 364 / a));
  }
  return a >= 1 ? RenderPlan(WSize.small, Size(170 * a, 170)) : RenderPlan(WSize.small, Size(170, 170 / a));
}

/// The face for any plan: full layout, or the one-row glance.
Widget buildFace(WDef def, WStyle style, RenderPlan p, {bool live = true}) {
  final c = WCtx(style, p.size, live: live, dims: p.logical);
  if (!p.strip) return def.face(c);
  if (isAdaptive(def.id) && Platform.isAndroid) return def.face(c);
  return StripFace(def, c);
}

/// Single-row layout: icon, big value, one line of detail, optional progress.
class StripFace extends StatelessWidget {
  const StripFace(this.def, this.c, {super.key});
  final WDef def;
  final WCtx c;

  @override
  Widget build(BuildContext context) {
    // Building the full face once triggers its data fetches (weather, prices…).
    def.face(c);
    final g = glances[def.id]?.call(c) ?? Glance(def.name, icon: def.icon);
    final d = c.dims;
    final padH = d.height < 70 ? 12.0 : 16.0;
    final innerW = d.width - padH * 2;
    final long = g.value.length > 26;
    final col = g.color ?? c.fg;
    final iconSize = (d.height * 0.34).clamp(18.0, 30.0);
    return WShell(
      c: c,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: innerW,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (g.icon != null && d.width >= 110) ...[
                  Icon(g.icon, size: iconSize, color: col, shadows: c.glowFor(col)),
                  SizedBox(width: d.width >= 200 ? 12 : 8),
                ],
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (long)
                      Text(g.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(15, w: FontWeight.w600, h: 1.15))
                    else
                      fit(Text(g.value, maxLines: 1, style: c.t(d.width >= 200 ? 24 : 20, w: FontWeight.w600))),
                    if (g.label.isNotEmpty && !(long && d.height < 90))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(g.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(12.5, dim: true)),
                      ),
                  ]),
                ),
                if (g.trailing != null && d.width >= 240)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(g.trailing!, maxLines: 1, style: c.t(13, dim: true)),
                  ),
              ]),
              if (g.progress != null) ...[
                const SizedBox(height: 7),
                GlowBar(c, g.progress!.clamp(0.0, 1.0), height: 4, color: g.color),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// A live, self-updating widget face.
class WidgetFace extends StatelessWidget {
  const WidgetFace(this.def, this.size, {super.key, this.style, this.live = true, this.dims});
  final WDef def;
  final WSize size;
  final WStyle? style;
  final bool live;

  /// Real size (dp). When set, the face adapts to it like on the home screen.
  final Size? dims;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.listen,
        builder: (context, _) {
          final st = style ?? app.settings.styleFor(def.id);
          if (dims != null) return buildFace(def, st, planFor(dims!.width, dims!.height), live: live);
          return def.face(WCtx(st, size, live: live));
        },
      );
}
