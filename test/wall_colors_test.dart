import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:so_widget/core/style.dart';
import 'package:so_widget/core/wall_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

double max(double a, double b) => a > b ? a : b;
double min(double a, double b) => a < b ? a : b;

void main() {
  test('wallpaper suggestions are readable and keep layout', () {
    for (final colors in [
      [const Color(0xFF0B1A3A), const Color(0xFFE04F8A), const Color(0xFF2B6CB0)],
      [const Color(0xFF101010), const Color(0xFF202020)],
      [const Color(0xFFF2E8D8), const Color(0xFFC08040)],
      [const Color(0xFF7A9A3A)],
    ]) {
      final list = suggestFrom(colors);
      expect(list, hasLength(4));
      for (final s in list) {
        expect(_contrast(s.bg, s.fg), greaterThan(7), reason: s.name);
      }
      final mine = WStyle.graphite.copyWith(textScale: 0.85, border: false, borderWidth: 2, radius: 20);
      final applied = list.first.applyTo(mine);
      expect(applied.textScale, 0.85);
      expect(applied.border, isFalse);
      expect(applied.radius, 20);
      expect(list.first.matches(applied), isTrue);
    }
    expect(suggestFrom(const [Color(0xFFF2E8D8)], lightWallpaper: true).first.name, 'Light');
  });

  test('themes keep the personal layout', () {
    final mine = WStyle.graphite.copyWith(textScale: 1.1, borderWidth: 2.5, weight: 1, compact: true);
    final next = keepLayout(kPresets[5].style, mine);
    expect(next.bg, kPresets[5].style.bg);
    expect(next.textScale, 1.1);
    expect(next.borderWidth, 2.5);
    expect(next.weight, 1);
    expect(next.compact, isTrue);
  });
}
