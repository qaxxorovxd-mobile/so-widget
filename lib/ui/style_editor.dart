import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/style.dart';
import 'forms.dart';
import 'kit.dart' show useGoogleFonts, fallbackFontFamily;

/// Full style editor: presets, colors, glow, fonts and shape.
class StyleEditor extends StatelessWidget {
  const StyleEditor({
    super.key,
    required this.style,
    required this.onChanged,
    this.presets = true,
  });
  final WStyle style;
  final ValueChanged<WStyle> onChanged;
  final bool presets;

  TextStyle _font(
    String f,
    double size, {
    Color color = K.label,
    FontWeight w = FontWeight.w600,
  }) {
    if (!useGoogleFonts) {
      return TextStyle(
        fontFamily: fallbackFontFamily,
        fontSize: size,
        color: color,
        fontWeight: w,
      );
    }
    try {
      return GoogleFonts.getFont(
        f,
        fontSize: size,
        color: color,
        fontWeight: w,
      );
    } catch (_) {
      return TextStyle(fontSize: size, color: color, fontWeight: w);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (presets) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 8),
            child: Text(
              'PRESETS',
              style: TextStyle(
                fontSize: 12.5,
                color: K.label2,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(
            height: 90 + MediaQuery.textScalerOf(context).scale(12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kPresets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = kPresets[i];
                final selected = p.style.sameAs(s);
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '${p.name} preset',
                  child: GestureDetector(
                    onTap: () {
                      tapFeedback();
                      onChanged(p.style);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: p.style.bg,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selected ? Colors.white : Colors.white12,
                                width: selected ? 2 : 1,
                              ),
                            ),
                          ),
                          child: Text(
                            'Aa',
                            style: _font(p.style.font, 24, color: p.style.fg)
                                .copyWith(
                                  shadows: p.style.glow
                                      ? [
                                          Shadow(
                                            color: p.style.accent.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? K.label : K.label2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
        ],
        Section(
          title: 'Colors',
          children: [
            _ColorRow('Background', s.bg, (c) => onChanged(s.copyWith(bg: c))),
            _ColorRow('Text', s.fg, (c) => onChanged(s.copyWith(fg: c))),
            _ColorRow(
              'Accent',
              s.accent,
              (c) => onChanged(s.copyWith(accent: c)),
            ),
          ],
        ),
        Section(
          title: 'Glow',
          footer: 'Soft light around text, bars and rings.',
          children: [
            SwitchRow(
              'Glow',
              s.glow,
              (v) => onChanged(s.copyWith(glow: v)),
              icon: CupertinoIcons.sun_max,
            ),
            if (s.glow)
              SliderRow(
                'Intensity',
                s.glowStrength,
                (v) => onChanged(s.copyWith(glowStrength: v)),
                label: '${(s.glowStrength * 100).round()}%',
              ),
            if (s.glow)
              SwitchRow(
                'Text glow',
                s.textGlow,
                (v) => onChanged(s.copyWith(textGlow: v)),
              ),
          ],
        ),
        Section(
          title: 'Layout & text',
          children: [
            SliderRow(
              'Text size',
              s.textScale,
              (v) => onChanged(s.copyWith(textScale: v)),
              min: 0.8,
              max: 1.15,
              divisions: 7,
              label: '${(s.textScale * 100).round()}%',
            ),
            SliderRow(
              'Font weight',
              s.weight.toDouble(),
              (v) => onChanged(s.copyWith(weight: v.round())),
              min: -2,
              max: 2,
              divisions: 4,
              label: const ['Light', 'Regular', 'Default', 'Bold', 'Heavy'][s.weight + 2],
            ),
            SwitchRow(
              'Compact spacing',
              s.compact,
              (v) => onChanged(s.copyWith(compact: v)),
              subtitle: 'More room for widget content',
            ),
          ],
        ),
        _chips(
          context,
          'Font',
          kFonts,
          s.font,
          (f) => onChanged(s.copyWith(font: f)),
          (f) => _font(f, 22),
        ),
        _chips(
          context,
          'Script font',
          kScriptFonts,
          s.scriptFont,
          (f) => onChanged(s.copyWith(scriptFont: f)),
          (f) => _font(f, 26, w: FontWeight.w400),
        ),
        Section(
          title: 'Shape',
          children: [
            SliderRow(
              'Corner radius',
              s.radius,
              (v) => onChanged(s.copyWith(radius: v)),
              min: 12,
              max: 56,
              label: '${s.radius.round()}',
            ),
            SwitchRow(
              'Sheen',
              s.sheen,
              (v) => onChanged(s.copyWith(sheen: v)),
              subtitle: 'Subtle light gradient on the surface',
            ),
            SliderRow(
              'Background opacity',
              s.bgOpacity,
              (v) => onChanged(s.copyWith(bgOpacity: v)),
              min: 0.25,
              max: 1,
              divisions: 15,
              label: '${(s.bgOpacity * 100).round()}%',
            ),
          ],
        ),
        Section(
          title: 'Outline',
          footer: 'One line around every widget, so they all sit on the same edge.',
          children: [
            SwitchRow(
              'Outline',
              s.border,
              (v) => onChanged(s.copyWith(border: v)),
              subtitle: 'Thin line around the widget',
            ),
            if (s.border) ...[
              SliderRow(
                'Line width',
                s.borderWidth,
                (v) => onChanged(s.copyWith(borderWidth: v)),
                min: 0.5,
                max: 3,
                divisions: 10,
                label: s.borderWidth.toStringAsFixed(2),
              ),
              SliderRow(
                'Line brightness',
                s.borderOpacity,
                (v) => onChanged(s.copyWith(borderOpacity: v)),
                min: 0.04,
                max: 0.6,
                divisions: 14,
                label: '${(s.borderOpacity * 100).round()}%',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chips(
    BuildContext context,
    String title,
    List<String> fonts,
    String value,
    ValueChanged<String> onTap,
    TextStyle Function(String) styleOf,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12.5,
              color: K.label2,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 40 + MediaQuery.textScalerOf(context).scale(48),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: fonts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final f = fonts[i];
              final sel = f == value;
              return GestureDetector(
                onTap: () {
                  tapFeedback();
                  onTap(f);
                },
                child: Container(
                  width: 96,
                  decoration: ShapeDecoration(
                    color: sel ? Colors.white : K.card,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Aa',
                        style: styleOf(f)
                            .copyWith(color: sel ? Colors.black : Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: sel ? Colors.black54 : K.label2,
                        ),
                      ),
                      if (kFontNotes[f] != null)
                        Text(
                          kFontNotes[f]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: sel ? const Color(0xFF0A84FF) : const Color(0xFF64D2FF),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ColorRow extends StatelessWidget {
  const _ColorRow(this.title, this.color, this.onChanged);
  final String title;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) => RowItem(
    title: title,
    value: hexOf(color),
    trailing: Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
      ),
    ),
    onTap: () => showSheet(
      context,
      ColorPicker(initial: color, onChanged: onChanged),
      title: title,
    ),
  );
}

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final hex = TextEditingController(text: hexOf(widget.initial));

  void _set(HSVColor v, {bool updateHex = true}) {
    setState(() => hsv = v);
    if (updateHex) hex.text = hexOf(v.toColor());
    widget.onChanged(v.toColor());
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = hsv.toColor();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: ShapeDecoration(
                    color: c,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: CupertinoTextField(
                    controller: hex,
                    style: const TextStyle(
                      color: K.label,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                    decoration: BoxDecoration(
                      color: K.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(14),
                    onChanged: (v) {
                      final p = parseHex(v);
                      if (p != null) {
                        _set(HSVColor.fromColor(p), updateHex: false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in kSwatches)
                  GestureDetector(
                    onTap: () {
                      tapFeedback();
                      _set(HSVColor.fromColor(s));
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: s,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.toARGB32() == c.toARGB32()
                              ? Colors.white
                              : Colors.white24,
                          width: s.toARGB32() == c.toARGB32() ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Section(
            children: [
              _gradientSlider('Hue', hsv.hue / 360, [
                for (var h = 0; h <= 360; h += 60)
                  HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
              ], (v) => _set(hsv.withHue(v * 360))),
              _gradientSlider('Saturation', hsv.saturation, [
                hsv.withSaturation(0).toColor(),
                hsv.withSaturation(1).toColor(),
              ], (v) => _set(hsv.withSaturation(v))),
              _gradientSlider('Brightness', hsv.value, [
                Colors.black,
                hsv.withValue(1).toColor(),
              ], (v) => _set(hsv.withValue(v))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gradientSlider(
    String label,
    double v,
    List<Color> colors,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: K.label2, fontSize: 13)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, bc) {
            void handle(Offset p) =>
                onChanged((p.dx / bc.maxWidth).clamp(0.0, 1.0));
            return GestureDetector(
              onPanDown: (d) => handle(d.localPosition),
              onPanUpdate: (d) => handle(d.localPosition),
              child: SizedBox(
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      top: 13,
                      bottom: 13,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(colors: colors),
                        ),
                      ),
                    ),
                    Positioned(
                      left: v.clamp(0.0, 1.0) * bc.maxWidth - 13,
                      top: 9,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
