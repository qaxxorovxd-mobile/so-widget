import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/state.dart';
import '../core/wall_colors.dart';
import 'forms.dart';

/// Top of Studio: widget colors that match the current home-screen wallpaper.
class WallpaperMatch extends StatefulWidget {
  const WallpaperMatch({super.key});

  @override
  State<WallpaperMatch> createState() => _WallpaperMatchState();
}

class _WallpaperMatchState extends State<WallpaperMatch> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    wallColors.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) wallColors.refresh();
  }

  void _apply(WallSuggestion sug) {
    tapFeedback();
    final s = app.settings;
    s.setGlobal(sug.applyTo(s.global));
    wallColors.markSeen();
    toast(context, '${sug.name} colors applied · text size and outline kept');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([wallColors, app.settings]),
        builder: (context, _) {
          final colors = wallColors.colors;
          if (colors.isEmpty) return const SizedBox.shrink();
          final isNew = wallColors.isNew;
          final global = app.settings.global;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(colors.first.withValues(alpha: 0.22), K.card),
                      K.card,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 18.0 + 12 * (colors.length - 1),
                            height: 18,
                            child: Stack(children: [
                              for (var i = colors.length - 1; i >= 0; i--)
                                Positioned(
                                  left: 12.0 * i,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: colors[i],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: K.card, width: 1.5),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isNew ? 'New wallpaper' : 'Matches your wallpaper',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: K.label),
                                ),
                                Text(
                                  isNew ? 'Pick widget colors that suit it' : 'Widget colors from your home screen',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: K.label2),
                                ),
                              ],
                            ),
                          ),
                          if (isNew)
                            CupertinoButton(
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                              onPressed: wallColors.markSeen,
                              child: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: K.label3),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          children: [
                            for (final (i, sug) in wallColors.suggestions.indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: _Tile(sug, selected: sug.matches(global), onTap: () => _apply(sug))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _Tile extends StatelessWidget {
  const _Tile(this.sug, {required this.selected, required this.onTap});
  final WallSuggestion sug;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '${sug.name} colors',
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: sug.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? K.label : sug.fg.withValues(alpha: 0.14),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(color: sug.accent, shape: BoxShape.circle),
                        ),
                        const Spacer(),
                        if (selected) Icon(CupertinoIcons.checkmark_alt, size: 12, color: sug.fg),
                      ]),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '9:41',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: sug.fg, height: 1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: 0.7,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(color: sug.accent, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(sug.name, maxLines: 1, style: const TextStyle(fontSize: 12, color: K.label2)),
              ),
            ],
          ),
        ),
      );
}
