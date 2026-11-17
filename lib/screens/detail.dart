import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/home_sync.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/style_editor.dart';
import 'picker.dart';

class DetailPage extends StatefulWidget {
  const DetailPage(this.def, {super.key, this.homeWid});
  final WDef def;

  /// Set when opened by tapping a widget on the home screen.
  final int? homeWid;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final HomeInstance? _home = HomeSync.placed.value
      .where((i) => i.wid == widget.homeWid)
      .firstOrNull;
  late WSize _size = _home?.size ?? widget.def.preferred;
  bool _placing = false;

  Future<void> _changeHome() async {
    final d = await pickWidget(context, _size, current: widget.def.id);
    if (d == null || d.id == widget.def.id || !mounted) return;
    if (widget.homeWid != null) {
      final inst = _home ?? HomeInstance(widget.homeWid!, _size, widget.def.id);
      await HomeSync.assign(inst, d.id);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DetailPage(d, homeWid: widget.homeWid)),
    );
  }

  Future<void> _addToHome() async {
    setState(() => _placing = true);
    final msg = await HomeSync.place(widget.def.id, _size);
    if (!mounted) return;
    setState(() => _placing = false);
    toast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.def;
    final mq = MediaQuery.of(context);
    final maxW = (mq.size.width - mq.padding.horizontal).clamp(0.0, 720.0) - 64;
    final logical = _size.logical;
    final previewHeight = (mq.size.height * 0.38).clamp(170.0, 340.0);
    final scale = (maxW / logical.width)
        .clamp(0.0, (previewHeight - 32) / logical.height)
        .clamp(0.0, 1.2);
    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4, mq.padding.top + 4, 16, 0),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => Navigator.pop(context),
                          child: const Row(
                            children: [
                              Icon(
                                CupertinoIcons.chevron_left,
                                color: K.label,
                                size: 22,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Widgets',
                                style: TextStyle(color: K.label, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'No. ${d.number}',
                          style: const TextStyle(color: K.label3, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    height: previewHeight,
                    decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(34),
                      ),
                      gradient: const RadialGradient(
                        center: Alignment(0, -0.3),
                        radius: 1.1,
                        colors: [Color(0xFF2A2A2E), Color(0xFF0B0B0C)],
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.94, end: 1.0).animate(a),
                            child: child,
                          ),
                        ),
                        child: SizedBox(
                          key: ValueKey(_size),
                          width: logical.width * scale,
                          height: logical.height * scale,
                          child: FittedBox(child: WidgetFace(d, _size)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.homeWid == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Seg<WSize>(
                        value: _size,
                        items: {for (final s in WSize.values) s: s.label},
                        onChanged: (v) => setState(() => _size = v),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: K.label,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.desc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: K.label2,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.cat.label} · ${_size.label}',
                          style: const TextStyle(fontSize: 12, color: K.label3),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 26),
                    child: Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            'Style',
                            icon: CupertinoIcons.paintbrush_fill,
                            filled: false,
                            onTap: () => _styleSheet(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: PillButton(
                            _placing ? 'Adding…' : 'Add widget',
                            icon: CupertinoIcons.add,
                            onTap: _placing ? null : _addToHome,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _SizesStrip(d)),
                SliverToBoxAdapter(
                  child: Section(
                    footer: widget.homeWid == null
                        ? null
                        : 'Changes the content of this home-screen widget.',
                    children: [
                      RowItem(
                        icon: CupertinoIcons.arrow_2_squarepath,
                        iconColor: K.blue,
                        title: 'Change widget',
                        subtitle: 'Search, preview and select',
                        onTap: _changeHome,
                      ),
                    ],
                  ),
                ),
                if (d.editor != null)
                  SliverToBoxAdapter(child: d.editor!(context)),
                SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.bottom + 30),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _styleSheet(BuildContext context) => showSheet(
    context,
    SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: _WidgetStyle(widget.def, _size),
    ),
    title: '${widget.def.name} style',
  );
}

class _WidgetStyle extends StatefulWidget {
  const _WidgetStyle(this.def, this.size);
  final WDef def;
  final WSize size;

  @override
  State<_WidgetStyle> createState() => _WidgetStyleState();
}

class _WidgetStyleState extends State<_WidgetStyle> {
  late final _original = app.settings.styleFor(widget.def.id);
  late final _wasCustom = app.settings.hasOverride(widget.def.id);
  late WStyle _draft = _original;
  late bool _custom = _wasCustom;

  void _edit(WStyle style) => setState(() {
    _draft = style;
    _custom = true;
  });

  Future<void> _copyStyle() async {
    final source = await pickWidget(
      context,
      widget.size,
      current: widget.def.id,
    );
    if (source != null && mounted) _edit(app.settings.styleFor(source.id));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final previewHeight = (bounds.maxHeight * 0.23).clamp(60.0, 140.0);
      return Column(
        children: [
          if (bounds.maxHeight > 300)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: previewHeight,
                width: double.infinity,
                child: FittedBox(
                  child: IgnorePointer(
                    child: WidgetFace(widget.def, widget.size, style: _draft),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                Section(
                  footer: _custom
                      ? 'Preview only. Apply saves the style for ${widget.def.name}.'
                      : 'Follows the shared Studio style.',
                  children: [
                    SwitchRow(
                      'Use Studio style',
                      !_custom,
                      (v) => setState(() {
                        _custom = !v;
                        if (v) _draft = app.settings.global;
                      }),
                    ),
                    RowItem(
                      title: 'Copy style from widget',
                      icon: CupertinoIcons.doc_on_doc,
                      onTap: _copyStyle,
                    ),
                    RowItem(
                      title: 'Undo changes',
                      icon: CupertinoIcons.arrow_counterclockwise,
                      onTap: () => setState(() {
                        _draft = _original;
                        _custom = _wasCustom;
                      }),
                    ),
                  ],
                ),
                StyleEditor(style: _draft, onChanged: _edit),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: PillButton(
                    'Cancel',
                    filled: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PillButton(
                    'Apply style',
                    onTap: () {
                      app.settings.setOverride(
                        widget.def.id,
                        _custom ? _draft : null,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Every home-screen size, live. Resizing on the home screen picks one of these automatically.
class _SizesStrip extends StatelessWidget {
  const _SizesStrip(this.def);
  final WDef def;

  static const _cells = {
    '2×1': Size(170, 80),
    '4×1': Size(360, 80),
    '2×2': Size(170, 170),
    '2×3': Size(170, 260),
    '3×2': Size(260, 170),
    '4×2': Size(360, 170),
    '4×3': Size(360, 260),
    '4×4': Size(360, 380),
  };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 4),
            child: Text('EVERY SIZE', style: TextStyle(fontSize: 12.5, color: K.label2, letterSpacing: 0.3)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 10),
            child: Text('Long-press the widget on your home screen and drag its edges. It adapts automatically.',
                style: TextStyle(fontSize: 12.5, color: K.label3, height: 1.3)),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cells.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final e = _cells.entries.elementAt(i);
                final h = 118.0;
                final w = (e.value.width / e.value.height * h).clamp(60.0, 300.0);
                return Column(children: [
                  SizedBox(
                    width: w,
                    height: h,
                    child: FittedBox(child: IgnorePointer(child: WidgetFace(def, WSize.small, dims: e.value))),
                  ),
                  const SizedBox(height: 8),
                  Text(e.key, style: const TextStyle(fontSize: 12, color: K.label2)),
                ]);
              },
            ),
          ),
        ]),
      );
}