import 'package:cupertino_ui/cupertino_ui.dart';
import '../core/state.dart';
import '../core/style.dart';
import 'forms.dart';
import 'style_editor.dart';

class ThemeStudio extends StatelessWidget {
  const ThemeStudio({super.key});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    return Column(children: [
      Section(title: 'Themes · 10 collections',
        footer: 'Tap a theme to apply its colors and fonts to every widget. Tap “Apply to all widgets” to update your home screen. Text size, outline and corners stay the same across themes.',
        children: [Padding(padding: const EdgeInsets.all(12), child: LayoutBuilder(builder: (context, bounds) => Wrap(
          spacing: 10, runSpacing: 10,
          children: [for (final p in kPresets) SizedBox(
            width: (bounds.maxWidth - 10) / 2,
            child: Semantics(selected: s.themeName == p.name, child: CupertinoButton(
              padding: const EdgeInsets.all(12),
              color: (s.themeStyles[p.name] ?? p.style).bg,
              borderRadius: BorderRadius.circular(16),
              onPressed: () { tapFeedback(); s.applyTheme(p.name); },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 20, height: 20, decoration: BoxDecoration(
                    color: (s.themeStyles[p.name] ?? p.style).accent, shape: BoxShape.circle)),
                  const Spacer(),
                  if (s.themeName == p.name) Icon(CupertinoIcons.checkmark_circle_fill,
                    size: 20, color: (s.themeStyles[p.name] ?? p.style).fg),
                ]),
                const SizedBox(height: 10),
                Text(p.name, style: TextStyle(fontSize: 13, color: (s.themeStyles[p.name] ?? p.style).fg)),
              ]),
            )),
          )],
        )))],
      ),
      Section(title: '${s.themeName} · personalize', children: [
        RowItem(title: 'Main color', value: hexOf(s.global.accent),
          trailing: Padding(padding: const EdgeInsets.only(left: 8), child: Container(
            width: 24, height: 24, decoration: BoxDecoration(color: s.global.accent,
              shape: BoxShape.circle, border: Border.all(color: K.label2)))),
          onTap: () => showSheet(context, ColorPicker(initial: s.global.accent, onChanged: s.setMainColor), title: 'Theme main color')),
        RowItem(title: 'Theme font', value: s.global.font, onTap: () => showSheet(context,
          SingleChildScrollView(child: Section(children: [for (final font in kFonts) RowItem(
            title: font, trailing: font == s.global.font ? const Icon(CupertinoIcons.checkmark, color: K.green) : null,
            onTap: () { s.setGlobal(s.global.copyWith(font: font, scriptFont: font)); Navigator.pop(context); },
          )])), title: 'Font for all widgets')),
        RowItem(title: 'Restore this theme', subtitle: 'Reset its colors and fonts',
          icon: CupertinoIcons.arrow_counterclockwise, onTap: () => s.applyTheme(s.themeName, reset: true)),
      ]),
    ]);
  }
}
