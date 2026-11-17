import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/home_sync.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/location.dart';
import '../ui/style_editor.dart';
import '../ui/theme_studio.dart';
import '../ui/media_controls.dart';
import 'picker.dart';

class StudioPage extends StatelessWidget {
  const StudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: app.settings,
      builder: (context, _) {
        final s = app.settings;
        return Stack(children: [
          ListView(
          padding: EdgeInsets.only(top: top + 18, bottom: 120),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 2),
              child: Text(
                'Studio',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: K.label,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                '10 themes. Your colors and fonts. Every widget, together.',
                style: TextStyle(fontSize: 13, color: K.label2, height: 1.4),
              ),
            ),
            SizedBox(
              height: 172,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final id in [
                    'chrono',
                    'power',
                    'atmosphere',
                    'focus',
                    'calendar',
                    'moon',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: FittedBox(
                          child: WidgetFace(
                            widgetById[id]!,
                            WSize.small,
                            style: s.global,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const ThemeStudio(),
            StyleEditor(style: s.global, onChanged: s.setGlobal, presets: false),
            const LocationSection(),
            const MediaControls(),
            Section(
              title: 'General',
              children: [
                SwitchRow(
                  '24-hour time',
                  s.use24h,
                  (v) => s.update(() => s.use24h = v),
                  icon: CupertinoIcons.clock,
                ),
              ],
            ),
            const _HomeScreenSection(),
          ],
        ),
          const Positioned(left: 16, right: 16, bottom: 14, child: _ApplyBar()),
        ]);
      },
    );
  }
}

/// One tap: every widget follows the Studio style, and every widget on the home screen updates.
class _ApplyBar extends StatefulWidget {
  const _ApplyBar();

  @override
  State<_ApplyBar> createState() => _ApplyBarState();
}

class _ApplyBarState extends State<_ApplyBar> {
  bool _busy = false;

  Future<void> _apply() async {
    setState(() => _busy = true);
    final s = app.settings;
    final custom = s.overrides.length;
    s.clearOverrides();
    await HomeSync.syncAll();
    if (!mounted) return;
    setState(() => _busy = false);
    final n = HomeSync.placed.value.where((i) => i.id != null).length;
    toast(
      context,
      n == 0
          ? 'Style applied · add widgets to your home screen'
          : 'Applied to $n home-screen widget${n == 1 ? '' : 's'}${custom > 0 ? ' · $custom custom styles reset' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<HomeInstance>>(
        valueListenable: HomeSync.placed,
        builder: (context, list, _) {
          final n = list.where((i) => i.id != null).length;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0xDD000000), blurRadius: 24, spreadRadius: 6)],
            ),
            child: PillButton(
              _busy ? 'Applying…' : (n == 0 ? 'Apply to all widgets' : n == 1 ? 'Apply to 1 widget' : 'Apply to all $n widgets'),
              icon: CupertinoIcons.wand_stars,
              onTap: _busy ? null : _apply,
            ),
          );
        },
      );
}

class _HomeScreenSection extends StatefulWidget {
  const _HomeScreenSection();

  @override
  State<_HomeScreenSection> createState() => _HomeScreenSectionState();
}

class _HomeScreenSectionState extends State<_HomeScreenSection> {
  @override
  void initState() {
    super.initState();
    HomeSync.instances();
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<List<HomeInstance>>(
    valueListenable: HomeSync.placed,
    builder: (context, list, _) => Section(
      title: 'On your home screen',
      footer: HomeSync.supported
          ? 'Every home-screen widget shows its own So Widget. Tap one here to change it, '
                'or long-press it on the home screen and choose “Widget settings”. '
                'Snapshots refresh every minute while So Widget is open and when you leave the app.'
          : 'Home-screen placement works on Android. iOS needs a WidgetKit extension built in Xcode.',
      children: [
        if (HomeSync.supported && list.isEmpty)
          const RowItem(
            title: 'No widgets yet',
            subtitle: 'Open any widget and tap “Add to Home Screen”.',
          ),
        for (final inst in list)
          RowItem(
            icon: inst.def?.icon ?? CupertinoIcons.plus_square,
            iconColor: inst.def == null ? K.red : const Color(0xFF3A3A3C),
            title: inst.def?.name ?? 'Not chosen yet',
            subtitle: '${inst.size.label} widget',
            onTap: () async {
              final d = await pickWidget(context, inst.size, current: inst.id);
              if (d == null) return;
              await HomeSync.assign(inst, d.id);
              if (context.mounted) {
                toast(context, '${inst.size.label} widget now shows ${d.name}');
              }
            },
          ),
        if (HomeSync.supported)
          RowItem(
            icon: CupertinoIcons.arrow_clockwise,
            iconColor: K.green,
            title: 'Refresh home widgets now',
            chevron: false,
            onTap: () async {
              await HomeSync.syncAll();
              if (context.mounted) toast(context, 'Home widgets refreshed');
            },
          ),
      ],
    ),
  );
}
