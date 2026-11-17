import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/registry.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import 'detail.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  WCat? _cat;
  String _q = '';

  List<WDef> get _filtered => allWidgets.where((w) {
    if (_cat != null && w.cat != _cat) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return w.name.toLowerCase().contains(q) ||
        w.desc.toLowerCase().contains(q) ||
        w.number == q.padLeft(2, '0');
  }).toList();

  void _open(WDef d) =>
      Navigator.of(context)
          .push(CupertinoPageRoute(builder: (_) => DetailPage(d)));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final list = _filtered;
    final showFeatured = _cat == null && _q.isEmpty;
    final cats = WCat.values.where((c) => list.any((w) => w.cat == c)).toList();
    return LayoutBuilder(
      builder: (context, bounds) {
        final columns = (bounds.maxWidth / 180).floor().clamp(2, 4);
        final tileWidth = (bounds.maxWidth - 32 - (columns - 1) * 12) / columns;
        final captionHeight = MediaQuery.textScalerOf(context).scale(14) + 22;
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, top + 18, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'So Widget',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: K.label,
                              letterSpacing: -1.2,
                            ),
                          ),
                          Text(
                            '${allWidgets.length} widgets, crafted for your home screen',
                            style: const TextStyle(
                              fontSize: 13,
                              color: K.label2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipRSuperellipse(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/logo.webp',
                        width: 44,
                        height: 44,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: CupertinoSearchTextField(
                  backgroundColor: K.card,
                  style: const TextStyle(color: K.label, fontSize: 14),
                  placeholder: 'Search widgets',
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46 + (MediaQuery.textScalerOf(context).scale(13) - 13),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip(
                      'All',
                      _cat == null,
                      () => setState(() => _cat = null),
                    ),
                    for (final c in WCat.values)
                      _chip(
                        c.label,
                        _cat == c,
                        () => setState(() => _cat = _cat == c ? null : c),
                      ),
                  ],
                ),
              ),
            ),
            if (showFeatured) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(child: _Featured(onOpen: _open)),
            ],
            if (list.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No widgets match',
                    style: TextStyle(color: K.label2, fontSize: 16),
                  ),
                ),
              ),
            for (final cat in cats) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: K.label,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cat.tagline,
                        style: const TextStyle(fontSize: 12, color: K.label2),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    mainAxisExtent: tileWidth + captionHeight,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final d in list.where((w) => w.cat == cat))
                      _Card(d, onTap: () => _open(d)),
                  ]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      },
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: () {
        tapFeedback();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: sel ? Colors.white : K.card,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: sel ? Colors.black : K.label,
          ),
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card(this.def, {required this.onTap});
  final WDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      tapFeedback();
      onTap();
    },
    behavior: HitTestBehavior.opaque,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: FittedBox(
            child: IgnorePointer(child: WidgetFace(def, WSize.small)),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Text(
              def.number,
              style: const TextStyle(
                fontSize: 12,
                color: K.label3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                def.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: K.label,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Featured extends StatefulWidget {
  const _Featured({required this.onOpen});
  final ValueChanged<WDef> onOpen;

  @override
  State<_Featured> createState() => _FeaturedState();
}

class _FeaturedState extends State<_Featured> {
  final _ids = const [
    'chrono',
    'power',
    'atmosphere',
    'world',
    'github',
    'prayer',
  ];
  final _ctrl = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w =
        (MediaQuery.of(context).size.width -
                    MediaQuery.paddingOf(context).horizontal)
                .clamp(0.0, 720.0) *
            0.9 -
        12;
    final h = w * WSize.medium.logical.height / WSize.medium.logical.width;
    return Column(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _ids.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final d = widgetById[_ids[i]]!;
              return GestureDetector(
                onTap: () => widget.onOpen(d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    child: IgnorePointer(child: WidgetFace(d, WSize.medium)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _ids.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _page ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? Colors.white : K.label3,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
