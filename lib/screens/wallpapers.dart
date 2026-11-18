import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/state.dart';
import '../core/wallhaven.dart';
import '../ui/forms.dart';
import '../widgets/productivity.dart' show openUrl;
import 'wallpaper_view.dart';

Color wallTint(Wall w, [double alpha = 1]) {
  final hex = w.colors.isEmpty ? '1c1c1e' : w.colors.first.replaceAll('#', '');
  final v = int.tryParse(hex, radix: 16) ?? 0x1c1c1e;
  return Color(0xFF000000 | v).withValues(alpha: alpha);
}

/// Wallpapers tab: Wallhaven library with vibes, filters, search and a Saved collection.
class WallpapersPage extends StatefulWidget {
  const WallpapersPage({super.key, required this.active});

  /// The tab is visible. Nothing is loaded until it is opened for the first time.
  final bool active;

  @override
  State<WallpapersPage> createState() => _WallpapersPageState();
}

class _WallpapersPageState extends State<WallpapersPage> {
  final feed = WallFeed();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(WallpapersPage old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (widget.active && WallSaved.termsAccepted && !feed.started) feed.refresh();
  }

  @override
  void dispose() {
    feed.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _open(List<Wall> list, int i) async {
    final r = await Navigator.of(context).push<WallAction>(
      CupertinoPageRoute(builder: (_) => WallpaperViewer(items: list, index: i, feed: _saved ? null : feed)),
    );
    if (r == null || !mounted) return;
    setState(() => _saved = false);
    _top();
    switch (r) {
      case WallTag(:final id, :final name):
        _search.text = name;
        feed.setSearch('id:$id', label: name);
      case WallColor(:final hex):
        feed.setFilters(feed.filters.copyWith(color: hex));
    }
  }

  Future<void> _filters() async {
    final f = await showSheet<WFilters>(context, _FilterSheet(feed.filters), title: 'Filters');
    if (f != null) {
      _top();
      feed.setFilters(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: Listenable.merge([feed, app.store]),
      builder: (context, _) {
        final accepted = WallSaved.termsAccepted;
        return LayoutBuilder(builder: (context, bounds) {
          final cols = (bounds.maxWidth / 125).floor().clamp(3, 6);
          final saved = WallSaved.all();
          final list = _saved ? saved : feed.items;
          if (!_saved && accepted && feed.started && !feed.loading && !feed.done && feed.error == null && feed.items.length < cols * 6) {
            WidgetsBinding.instance.addPostFrameCallback((_) => feed.more());
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (!_saved && n.metrics.extentAfter < 1600) feed.more();
              return false;
            },
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _header(top)),
                if (!accepted)
                  SliverToBoxAdapter(child: _Terms(onAccept: () {
                    WallSaved.acceptTerms();
                    feed.refresh();
                  }))
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Seg<bool>(
                        value: _saved,
                        items: {false: 'Discover', true: 'Saved${saved.isEmpty ? '' : ' · ${saved.length}'}'},
                        onChanged: (v) => setState(() => _saved = v),
                      ),
                    ),
                  ),
                  if (!_saved) ...[
                    SliverToBoxAdapter(child: _searchBar()),
                    SliverToBoxAdapter(child: _vibes()),
                    SliverToBoxAdapter(child: _summary()),
                  ] else
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  if (list.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 9 / 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _Tile(list[i], saved: _saved || WallSaved.has(list[i].id), onTap: () => _open(List.of(list), i)),
                          childCount: list.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: _saved ? _savedFooter(saved.isEmpty) : _footer()),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _header(double top) => Padding(
        padding: EdgeInsets.fromLTRB(20, top + 18, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Wallpapers',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: K.label, letterSpacing: -1.2)),
                Text('4K, phone-sized, curated by vibe', style: TextStyle(fontSize: 13, color: K.label2)),
              ]),
            ),
            if (WallSaved.termsAccepted && !_saved)
              _RoundButton(
                icon: CupertinoIcons.slider_horizontal_3,
                badge: feed.filters.activeCount,
                onTap: _filters,
              ),
          ],
        ),
      );

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: CupertinoSearchTextField(
          controller: _search,
          backgroundColor: K.card,
          style: const TextStyle(color: K.label, fontSize: 14),
          placeholder: 'Search wallpapers, e.g. “black hole”',
          onSubmitted: (v) {
            _top();
            feed.setSearch(v);
          },
          onSuffixTap: () {
            _search.clear();
            if (feed.search.isNotEmpty) feed.setSearch('');
          },
          onChanged: (v) {
            if (v.isEmpty && feed.search.isNotEmpty) feed.setSearch('');
          },
        ),
      );

  Widget _vibes() => SizedBox(
        height: 40 + (MediaQuery.textScalerOf(context).scale(13) - 13),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final v in kVibes)
              _VibeChip(v, selected: feed.search.isEmpty && feed.vibe == v, onTap: () {
                _search.clear();
                _top();
                feed.setVibe(v);
              }),
          ],
        ),
      );

  Widget _summary() {
    final f = feed.filters;
    final parts = [
      f.quality.label,
      f.fit.label,
      if (f.sort != WSort.popular) f.sort == WSort.top ? 'Top · ${f.range.label}' : f.sort.label,
      if (feed.tone != WTone.any) feed.tone.label,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              feed.tagLabel != null && feed.search.startsWith('id:') ? '#${feed.tagLabel}' : feed.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: K.label, letterSpacing: -0.4),
            ),
          ),
          if (f.color != null)
            GestureDetector(
              onTap: () => feed.setFilters(f.copyWith(clearColor: true)),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                decoration: const ShapeDecoration(color: K.card, shape: StadiumBorder()),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _Swatch(f.color!, size: 16),
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.xmark, size: 11, color: K.label2),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 2),
        Text(
          [...parts, if (feed.total > 0) '${compactNum(feed.total)} found'].join(' · '),
          style: const TextStyle(fontSize: 12, color: K.label2),
        ),
        if (feed.relaxed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(CupertinoIcons.wand_stars, size: 14, color: Color(0xFFFF9F0A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No exact matches, so showing ${feed.relaxed.join(', ')}.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF9F0A)),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _footer() {
    if (feed.error != null) {
      return _Message(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: feed.error is WallhavenBusy ? 'Wallhaven is busy' : 'Couldn’t load wallpapers',
        text: feed.error is WallhavenBusy ? 'Too many requests. Wait a few seconds.' : 'Check your connection and try again.',
        action: 'Try again',
        onAction: feed.items.isEmpty ? feed.refresh : feed.more,
      );
    }
    if (feed.loading || !feed.started) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CupertinoActivityIndicator(radius: 12, color: K.label2)),
      );
    }
    if (feed.items.isEmpty) {
      return _Message(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Nothing here',
        text: 'Try another vibe or loosen the filters.',
        action: feed.filters.activeCount > 0 ? 'Reset filters' : null,
        onAction: () => feed.setFilters(WFilters.defaults),
      );
    }
    if (feed.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text('You’ve seen them all', style: TextStyle(color: K.label3, fontSize: 13))),
      );
    }
    return const SizedBox(height: 60);
  }

  Widget _savedFooter(bool empty) => empty
      ? const _Message(
          icon: CupertinoIcons.heart,
          title: 'No saved wallpapers',
          text: 'Tap the heart on any wallpaper to keep it here.',
        )
      : const SizedBox(height: 12);
}

// ───────────────────────── Tiles & chips ─────────────────────────

class _Tile extends StatelessWidget {
  const _Tile(this.w, {required this.saved, required this.onTap});
  final Wall w;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          tapFeedback();
          onTap();
        },
        child: Hero(
          tag: 'wall-${w.id}',
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: wallTint(w, 0.55)),
              Image.network(
                w.thumb,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                  opacity: frame == null && !sync ? 0 : 1,
                  duration: const Duration(milliseconds: 260),
                  child: child,
                ),
                errorBuilder: (_, _, _) => const Center(child: Icon(CupertinoIcons.photo, color: K.label3)),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: _Badge(w.quality),
              ),
              if (saved)
                const Positioned(
                  right: 7,
                  top: 7,
                  child: Icon(CupertinoIcons.heart_fill, size: 15, color: Colors.white, shadows: [Shadow(blurRadius: 6)]),
                ),
            ]),
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: ShapeDecoration(color: Colors.black.withValues(alpha: 0.55), shape: const StadiumBorder()),
        child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

class _VibeChip extends StatelessWidget {
  const _VibeChip(this.v, {required this.selected, required this.onTap});
  final Vibe v;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            tapFeedback();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
            decoration: ShapeDecoration(color: selected ? Colors.white : K.card, shape: const StadiumBorder()),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? Colors.black12 : Colors.white12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(v.tint[0]), Color(v.tint[1])],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                v.name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.black : K.label),
              ),
            ]),
          ),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.hex, {this.size = 30, this.selected = false});
  final String hex;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(0xFF000000 | (int.tryParse(hex.replaceAll('#', ''), radix: 16) ?? 0)),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected ? Icon(CupertinoIcons.checkmark, size: size * 0.5, color: lumaOf(hex) > 0.6 ? Colors.black : Colors.white) : null,
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          tapFeedback();
          onTap();
        },
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44,
            height: 44,
            decoration: const ShapeDecoration(color: K.card, shape: CircleBorder()),
            child: Icon(icon, size: 20, color: K.label),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: K.blue, shape: BoxShape.circle),
                child: Text('$badge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ]),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, this.action, this.onAction});
  final IconData icon;
  final String title, text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
        child: Column(children: [
          Icon(icon, size: 40, color: K.label3),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: K.label)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: K.label2)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 16),
            PillButton(action!, onTap: onAction, filled: false),
          ],
        ]),
      );
}

// ───────────────────────── Terms ─────────────────────────

class _Terms extends StatelessWidget {
  const _Terms({required this.onAccept});
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Colors.white10),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF26262A), Color(0xFF0E0E10)],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(CupertinoIcons.photo_on_rectangle, size: 34, color: Colors.white),
            const SizedBox(height: 14),
            const Text('Before you start',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: K.label, letterSpacing: -0.6)),
            const SizedBox(height: 10),
            for (final (icon, text) in const [
              (CupertinoIcons.globe, 'Wallpapers come from Wallhaven, a community library. So Widget does not host or own them.'),
              (CupertinoIcons.person_crop_circle_badge_checkmark, 'Every image keeps its credit: uploader, original source and a link back.'),
              (CupertinoIcons.house_fill, 'Use them as your personal wallpaper only. No resale, prints or redistribution.'),
              (CupertinoIcons.flag_fill, 'Own an image and want it removed? Report it on its Wallhaven page.'),
              (CupertinoIcons.checkmark_shield_fill, 'Only safe-for-work content is shown.'),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 18, color: K.label2),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: K.label2, height: 1.35))),
                ]),
              ),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: PillButton('I understand', onTap: onAccept)),
            const SizedBox(height: 8),
            Center(
              child: CupertinoButton(
                onPressed: () => openUrl('$kWallhaven/terms'),
                child: const Text('Wallhaven Terms of Service', style: TextStyle(fontSize: 13, color: K.label2)),
              ),
            ),
          ]),
        ),
      );
}

// ───────────────────────── Filter sheet ─────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(this.initial);
  final WFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late WFilters f = widget.initial;

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: K.label2, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
      );

  Widget _pad(Widget c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: c);

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 8), children: [
            _label('Sort'),
            _pad(Seg<WSort>(
              value: f.sort,
              items: {for (final s in WSort.values) s: s == WSort.views ? 'Views' : s.label},
              onChanged: (v) => setState(() => f = f.copyWith(sort: v)),
            )),
            if (f.sort == WSort.top) ...[
              const SizedBox(height: 8),
              _pad(Seg<WRange>(
                value: f.range,
                items: {for (final r in WRange.values) r: r.label},
                onChanged: (v) => setState(() => f = f.copyWith(range: v)),
              )),
            ],
            _label('Quality'),
            _pad(Seg<WQuality>(
              value: f.quality,
              items: {for (final q in WQuality.values) q: q.label},
              onChanged: (v) => setState(() => f = f.copyWith(quality: v)),
            )),
            _label('Shape'),
            _pad(Seg<WFit>(
              value: f.fit,
              items: {for (final x in WFit.values) x: x == WFit.phone ? 'Phone (9:16 – 9:21)' : x.label},
              onChanged: (v) => setState(() => f = f.copyWith(fit: v)),
            )),
            _label('Brightness'),
            _pad(Seg<WTone>(
              value: f.tone,
              items: {for (final t in WTone.values) t: t == WTone.amoled ? 'AMOLED black' : t.label},
              onChanged: (v) => setState(() => f = f.copyWith(tone: v)),
            )),
            _label('Color'),
            _pad(Wrap(spacing: 10, runSpacing: 10, children: [
              GestureDetector(
                onTap: () => setState(() => f = f.copyWith(clearColor: true)),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: f.color == null ? Colors.white : Colors.white24, width: f.color == null ? 2.5 : 1),
                    gradient: const SweepGradient(colors: [
                      Color(0xFFFF453A), Color(0xFFFFD60A), Color(0xFF30D158), Color(0xFF64D2FF), Color(0xFFBF5AF2), Color(0xFFFF453A), //
                    ]),
                  ),
                ),
              ),
              for (final c in kWallColors)
                GestureDetector(
                  onTap: () {
                    tapFeedback();
                    setState(() => f = f.copyWith(color: c));
                  },
                  child: _Swatch(c, selected: f.color == c),
                ),
            ])),
            _label('Content'),
            Section(
              footer: 'Only safe-for-work wallpapers are ever shown. People is off by default to respect the privacy of real persons.',
              children: [
                SwitchRow('General', f.general, (v) => setState(() => f = f.copyWith(general: v)),
                    icon: CupertinoIcons.photo),
                SwitchRow('Anime & illustration', f.anime, (v) => setState(() => f = f.copyWith(anime: v)),
                    icon: CupertinoIcons.paintbrush),
                SwitchRow('People', f.people, (v) => setState(() => f = f.copyWith(people: v)),
                    icon: CupertinoIcons.person_2),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            Expanded(child: PillButton('Reset', filled: false, onTap: () => setState(() => f = WFilters.defaults))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: PillButton('Show wallpapers', onTap: () => Navigator.of(context).pop(f))),
          ]),
        ),
      ]);
}
