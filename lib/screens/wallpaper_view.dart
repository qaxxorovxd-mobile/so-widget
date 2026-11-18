import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/state.dart';
import '../core/style.dart' show parseHex;
import '../core/wall_colors.dart';
import '../core/wallhaven.dart';
import '../ui/forms.dart';
import '../widgets/productivity.dart' show openUrl;
import 'wallpapers.dart' show wallTint;

/// What the viewer asks the library to do when it closes.
sealed class WallAction {
  const WallAction();
}

class WallTag extends WallAction {
  const WallTag(this.id, this.name);
  final int id;
  final String name;
}

class WallColor extends WallAction {
  const WallColor(this.hex);
  final String hex;
}

/// Per-wallpaper state: full-resolution download, crop alignment and credits.
class _Ctl extends ChangeNotifier {
  _Ctl(this.wall);
  final Wall wall;

  File? file;
  double progress = 0;
  Object? error;
  Alignment align = Alignment.center;
  Map<String, dynamic>? info;
  bool _infoLoading = false;
  WallCancel? _cancel;
  Completer<File?>? _job;
  bool _disposed = false;

  bool get downloading => _job != null && file == null;

  Future<File?> ensure() {
    if (file != null) return Future.value(file);
    final running = _job;
    if (running != null) return running.future;
    final job = _job = Completer<File?>();
    error = null;
    progress = 0;
    _notify();
    final cancel = _cancel = WallCancel();
    WallFiles.fetch(wall, cancel: cancel, onProgress: (p) {
      if ((p - progress).abs() >= 0.01 || p == 1) {
        progress = p;
        _notify();
      }
    }).then((f) {
      file = f;
      progress = 1;
      job.complete(f);
    }).catchError((Object e) {
      if (!isCancel(e)) error = e;
      job.complete(null);
    }).whenComplete(() {
      _job = null;
      _notify();
    });
    return job.future;
  }

  /// Stops a download that is no longer needed (user swiped away).
  void park() {
    if (file == null) _cancel?.cancel();
  }

  Future<void> loadInfo() async {
    if (info != null || _infoLoading) return;
    _infoLoading = true;
    try {
      info = await Wallhaven.info(wall.id);
    } catch (_) {}
    _infoLoading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}

class WallpaperViewer extends StatefulWidget {
  const WallpaperViewer({super.key, required this.items, required this.index, this.feed});
  final List<Wall> items;
  final int index;

  /// When opened from the library the pager keeps loading more wallpapers.
  final WallFeed? feed;

  @override
  State<WallpaperViewer> createState() => _WallpaperViewerState();
}

class _WallpaperViewerState extends State<WallpaperViewer> {
  late final _pager = PageController(initialPage: widget.index);
  late int _i = widget.index;
  late List<Wall> _items = widget.items;
  final _ctls = <String, _Ctl>{};
  bool _chrome = true;
  bool _adjust = false;
  bool _preview = false;
  String? _busy;
  Timer? _settle;

  _Ctl _ctl(Wall w) => _ctls.putIfAbsent(w.id, () => _Ctl(w));
  _Ctl get _cur => _ctl(_items[_i]);

  @override
  void initState() {
    super.initState();
    widget.feed?.addListener(_feedChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _onSettled();
  }

  void _feedChanged() {
    final f = widget.feed!;
    if (f.items.length > _items.length && f.items.take(_items.length).every((w) => _items.contains(w))) {
      setState(() => _items = List.of(f.items));
    }
  }

  void _onPage(int i) {
    setState(() {
      _i = i;
      _adjust = false;
    });
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 350), _onSettled);
    if (widget.feed != null && i >= _items.length - 4) widget.feed!.more();
  }

  void _onSettled() {
    if (!mounted) return;
    final cur = _cur;
    for (final c in _ctls.values) {
      if (c != cur) c.park();
    }
    cur.ensure();
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && _cur == cur) cur.loadInfo();
    });
    // Drop far-away controllers to free memory.
    final keep = {for (var k = max(0, _i - 2); k <= min(_items.length - 1, _i + 2); k++) _items[k].id};
    _ctls.removeWhere((id, c) {
      if (keep.contains(id)) return false;
      c.dispose();
      return true;
    });
  }

  @override
  void dispose() {
    widget.feed?.removeListener(_feedChanged);
    _settle?.cancel();
    for (final c in _ctls.values) {
      c.dispose();
    }
    _pager.dispose();
    super.dispose();
  }

  String _credit(Wall w, Map<String, dynamic>? info) {
    final by = info == null ? '' : Wallhaven.uploaderOf(info);
    return [
      'Wallhaven ${w.id}',
      if (by.isNotEmpty) 'uploaded by $by',
      if (w.source.isNotEmpty) 'source: ${w.source}',
      w.url,
    ].join(' | ');
  }

  Future<void> _download() async {
    final c = _cur;
    setState(() => _busy = 'Saving…');
    try {
      final f = await c.ensure();
      if (f == null) throw c.error ?? Exception('Download failed');
      await c.loadInfo();
      await WallNative.save(
        f,
        c.wall,
        credit: _credit(c.wall, c.info),
        artist: c.info == null ? '' : Wallhaven.uploaderOf(c.info!),
      );
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, 'Saved to Gallery · Pictures/So Widget');
    } on PlatformException catch (e) {
      if (mounted) toast(context, e.code == 'permission' ? 'Allow storage access, then try again' : 'Couldn’t save: ${e.message}');
    } catch (e) {
      if (mounted) toast(context, e is WallhavenBusy ? 'Wallhaven is busy, try again' : 'Couldn’t download the wallpaper');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _set() async {
    final target = await showSheet<String>(
      context,
      ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        children: [Section(children: [
          for (final (id, icon, title) in const [
            ('home', CupertinoIcons.house_fill, 'Home screen'),
            ('lock', CupertinoIcons.lock_fill, 'Lock screen'),
            ('both', CupertinoIcons.device_phone_portrait, 'Home & lock screen'),
          ])
            RowItem(
              icon: icon,
              iconColor: const Color(0xFF3A3A3C),
              title: title,
              onTap: () => Navigator.of(context).pop(id),
            ),
        ])],
      ),
      title: 'Set as wallpaper',
    );
    if (target == null || !mounted) return;
    final c = _cur;
    setState(() => _busy = 'Setting wallpaper…');
    try {
      final f = await c.ensure();
      if (f == null) throw c.error ?? Exception('Download failed');
      await WallNative.set(f, target, ax: (c.align.x + 1) / 2, ay: (c.align.y + 1) / 2);
      HapticFeedback.heavyImpact();
      if (target != 'lock') {
        wallColors.rememberSet(c.wall.colors.map(parseHex).whereType<Color>().toList());
      }
      if (mounted) {
        toast(context, switch (target) {
          'home' => 'Home screen wallpaper set',
          'lock' => 'Lock screen wallpaper set',
          _ => 'Wallpaper set',
        });
      }
    } on PlatformException catch (e) {
      if (mounted) toast(context, 'Couldn’t set wallpaper: ${e.message}');
    } catch (e) {
      if (mounted) toast(context, e is WallhavenBusy ? 'Wallhaven is busy, try again' : 'Couldn’t download the wallpaper');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _info() async {
    final c = _cur;
    c.loadInfo();
    final r = await showSheet<WallAction>(context, _Credits(c), title: 'About this wallpaper');
    if (r != null && mounted) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = _cur;
    final showChrome = _chrome && !_preview;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          PageView.builder(
            controller: _pager,
            physics: _adjust ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            itemCount: _items.length,
            onPageChanged: _onPage,
            itemBuilder: (context, i) => _WallImage(
              ctl: _ctl(_items[i]),
              hero: i == widget.index,
              adjust: _adjust && i == _i,
              onTap: () => setState(() {
                if (_preview) {
                  _preview = false;
                } else if (!_adjust) {
                  _chrome = !_chrome;
                }
              }),
            ),
          ),
          if (_preview) const IgnorePointer(child: _LockPreview()),
          // Top bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: showChrome ? 0 : -120,
            child: _Shade(
              top: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, mq.padding.top + 6, 12, 18),
                child: Row(children: [
                  _Glass(icon: CupertinoIcons.chevron_back, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${c.wall.quality} · ${c.wall.w}×${c.wall.h}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(
                        [c.wall.sizeLabel, '${compactNum(c.wall.favorites)} likes'].where((e) => e.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]),
                  ),
                  _Glass(
                    icon: CupertinoIcons.crop,
                    active: _adjust,
                    onTap: () => setState(() => _adjust = !_adjust),
                  ),
                  const SizedBox(width: 8),
                  _Glass(icon: CupertinoIcons.eye, onTap: () => setState(() => _preview = true)),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: app.store,
                    builder: (context, _) {
                      final saved = WallSaved.has(c.wall.id);
                      return _Glass(
                        icon: saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: saved ? const Color(0xFFFF375F) : Colors.white,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          WallSaved.toggle(c.wall);
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _Glass(icon: CupertinoIcons.info, onTap: _info),
                ]),
              ),
            ),
          ),
          // Bottom bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: showChrome ? 0 : -220,
            child: _Shade(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 30, 16, mq.padding.bottom + 14),
                child: ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_adjust)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Drag the image to choose what stays on screen',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      )
                    else
                      _CreditLine(ctl: c, onTap: _info),
                    if (c.error != null && !c.downloading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: c.ensure,
                          child: Text(
                            c.error is WallhavenBusy ? 'Wallhaven is busy · Tap to retry' : 'Download failed · Tap to retry',
                            style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Row(children: [
                      Expanded(
                        child: _ActionButton(
                          icon: CupertinoIcons.arrow_down_to_line,
                          label: 'Download',
                          onTap: _busy == null ? _download : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: _adjust ? CupertinoIcons.checkmark : CupertinoIcons.device_phone_portrait,
                          label: _adjust ? 'Done' : 'Set wallpaper',
                          primary: true,
                          onTap: _busy != null
                              ? null
                              : _adjust
                                  ? () => setState(() => _adjust = false)
                                  : _set,
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
          if (_busy != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: ListenableBuilder(
                    listenable: c,
                    builder: (context, _) => _BusyCard(text: _busy!, progress: c.file == null ? c.progress : null),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Image page ─────────────────────────

class _WallImage extends StatelessWidget {
  const _WallImage({required this.ctl, required this.hero, required this.adjust, required this.onTap});
  final _Ctl ctl;
  final bool hero, adjust;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = ctl.wall;
        final screen = box.biggest;
        // Size of the image when it covers the screen.
        final coverW = max(screen.width, screen.height * w.aspect);
        final coverH = max(screen.height, screen.width / w.aspect);
        final decodeW = min((coverW * dpr).round(), max(w.w, 1));
        return ListenableBuilder(
          listenable: ctl,
          builder: (context, _) {
            final thumb = Image.network(w.thumb, fit: BoxFit.cover, alignment: ctl.align, gaplessPlayback: true);
            Widget img = Stack(fit: StackFit.expand, children: [
              ColoredBox(color: wallTint(w)),
              ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: thumb),
              if (ctl.file != null)
                Image.file(
                  ctl.file!,
                  fit: BoxFit.cover,
                  alignment: ctl.align,
                  cacheWidth: decodeW,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                    opacity: frame == null && !sync ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: child,
                  ),
                ),
              if (ctl.file == null && ctl.error == null)
                Center(child: _Progress(ctl.progress)),
            ]);
            if (hero) img = Hero(tag: 'wall-${w.id}', child: img);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onPanUpdate: adjust
                  ? (d) {
                      final ox = coverW - screen.width, oy = coverH - screen.height;
                      ctl.align = Alignment(
                        ox <= 1 ? 0 : (ctl.align.x - d.delta.dx * 2 / ox).clamp(-1.0, 1.0),
                        oy <= 1 ? 0 : (ctl.align.y - d.delta.dy * 2 / oy).clamp(-1.0, 1.0),
                      );
                      ctl._notify();
                    }
                  : null,
              child: Stack(fit: StackFit.expand, children: [
                img,
                if (adjust) const IgnorePointer(child: _Grid()),
              ]),
            );
          },
        );
      });
}

class _Progress extends StatelessWidget {
  const _Progress(this.value);
  final double value;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 64,
            height: 64,
            color: Colors.black26,
            padding: const EdgeInsets.all(10),
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(
                value: value <= 0 ? null : value,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
              Center(
                child: Text(
                  value <= 0 ? '' : '${(value * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.8;
    for (var k = 1; k < 3; k++) {
      canvas.drawLine(Offset(size.width * k / 3, 0), Offset(size.width * k / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * k / 3), Offset(size.width, size.height * k / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lock-screen mock-up to judge how the wallpaper looks behind the clock.
class _LockPreview extends StatefulWidget {
  const _LockPreview();

  @override
  State<_LockPreview> createState() => _LockPreviewState();
}

class _LockPreviewState extends State<_LockPreview> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final h = app.settings.use24h ? two(now.hour) : '${now.hour % 12 == 0 ? 12 : now.hour % 12}';
    const shadow = [Shadow(blurRadius: 18, color: Colors.black38)];
    return SafeArea(
      child: Column(children: [
        const SizedBox(height: 40),
        Text('${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, shadows: shadow)),
        Text('$h:${two(now.minute)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 96,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -3,
              shadows: shadow,
            )),
        const Spacer(),
        const Text('Tap anywhere to exit preview', style: TextStyle(color: Colors.white70, fontSize: 13, shadows: shadow)),
        const SizedBox(height: 26),
      ]),
    );
  }
}

// ───────────────────────── Chrome ─────────────────────────

class _Shade extends StatelessWidget {
  const _Shade({required this.top, required this.child});
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: const [Color(0x99000000), Color(0x00000000)],
          ),
        ),
        child: child,
      );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.icon, required this.onTap, this.color = Colors.white, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          tapFeedback();
          onTap();
        },
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
              child: Icon(icon, size: 19, color: active ? Colors.black : color),
            ),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.5 : 1,
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 54,
              color: primary ? Colors.white : Colors.white.withValues(alpha: 0.18),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditLine extends StatelessWidget {
  const _CreditLine({required this.ctl, required this.onTap});
  final _Ctl ctl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = ctl.info;
    final by = info == null ? '' : Wallhaven.uploaderOf(info);
    final avatar = info == null ? null : Wallhaven.avatarOf(info);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          ClipOval(
            child: Container(
              width: 22,
              height: 22,
              color: Colors.white24,
              child: avatar != null && avatar.startsWith('http')
                  ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                  : const Icon(CupertinoIcons.person_fill, size: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                if (by.isNotEmpty) ...[
                  const TextSpan(text: 'by '),
                  TextSpan(text: by, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' · '),
                ],
                const TextSpan(text: 'via Wallhaven'),
                if (ctl.wall.source.isNotEmpty) const TextSpan(text: ' · source credited'),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, shadows: [Shadow(blurRadius: 8)]),
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, size: 13, color: Colors.white70),
        ]),
      ),
    );
  }
}

class _BusyCard extends StatelessWidget {
  const _BusyCard({required this.text, this.progress});
  final String text;
  final double? progress;

  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 190,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            color: Colors.black.withValues(alpha: 0.55),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CupertinoActivityIndicator(radius: 13, color: Colors.white),
              const SizedBox(height: 12),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              if (progress != null && progress! > 0 && progress! < 1) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: progress, minHeight: 4, color: Colors.white, backgroundColor: Colors.white24),
                ),
                const SizedBox(height: 6),
                Text('Downloading ${(progress! * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ]),
          ),
        ),
      );
}

// ───────────────────────── Credits sheet ─────────────────────────

class _Credits extends StatelessWidget {
  const _Credits(this.ctl);
  final _Ctl ctl;

  String _date(String s) {
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return s;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctl,
        builder: (context, _) {
          final w = ctl.wall;
          final info = ctl.info;
          final by = info == null ? '' : Wallhaven.uploaderOf(info);
          final avatar = info == null ? null : Wallhaven.avatarOf(info);
          final tags = info == null ? const <({int id, String name})>[] : Wallhaven.tagsOf(info);
          final source = Uri.tryParse(w.source);
          return ListView(shrinkWrap: true, padding: const EdgeInsets.only(top: 8, bottom: 16), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Row(children: [
                ClipOval(
                  child: Container(
                    width: 48,
                    height: 48,
                    color: K.card2,
                    child: avatar != null && avatar.startsWith('http')
                        ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                        : const Icon(CupertinoIcons.person_fill, color: K.label3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(by.isEmpty ? (info == null ? 'Loading…' : 'Unknown uploader') : by,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: K.label)),
                    const Text('Uploader on Wallhaven', style: TextStyle(fontSize: 13, color: K.label2)),
                  ]),
                ),
              ]),
            ),
            Section(children: [
              if (source != null && source.hasScheme && source.host.isNotEmpty)
                RowItem(
                  icon: CupertinoIcons.link,
                  iconColor: K.blue,
                  title: 'Original source',
                  value: source.host.replaceFirst('www.', ''),
                  onTap: () => openUrl(w.source),
                )
              else
                const RowItem(
                  icon: CupertinoIcons.link,
                  iconColor: Color(0xFF3A3A3C),
                  title: 'Original source',
                  value: 'Not provided',
                ),
              RowItem(
                icon: CupertinoIcons.globe,
                iconColor: const Color(0xFF3A3A3C),
                title: 'View on Wallhaven',
                value: 'whvn.cc/${w.id}',
                onTap: () => openUrl(w.url),
              ),
            ]),
            Section(title: 'Details', children: [
              RowItem(title: 'Resolution', value: '${w.w} × ${w.h} · ${w.quality}'),
              if (w.sizeLabel.isNotEmpty) RowItem(title: 'File size', value: '${w.sizeLabel} · ${w.ext.toUpperCase()}'),
              if (w.category.isNotEmpty) RowItem(title: 'Category', value: w.category[0].toUpperCase() + w.category.substring(1)),
              RowItem(title: 'Views', value: compactNum(w.views)),
              RowItem(title: 'Favorites', value: compactNum(w.favorites)),
              if (w.created.isNotEmpty) RowItem(title: 'Uploaded', value: _date(w.created)),
            ]),
            if (w.colors.isNotEmpty) ...[
              const _Head('Colors · tap to find similar'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c in w.colors)
                    GestureDetector(
                      onTap: () {
                        final hex = c.replaceAll('#', '').toLowerCase();
                        if (kWallColors.contains(hex)) Navigator.of(context).pop(WallColor(hex));
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(0xFF000000 | (int.tryParse(c.replaceAll('#', ''), radix: 16) ?? 0)),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
            if (tags.isNotEmpty) ...[
              const _Head('Tags · tap to explore'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in tags)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(WallTag(t.id, t.name)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: const ShapeDecoration(color: K.card, shape: StadiumBorder()),
                        child: Text('#${t.name}', style: const TextStyle(fontSize: 13, color: K.label)),
                      ),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            Section(
              footer: 'This image was shared on Wallhaven by its uploader. All rights belong to the original artist. '
                  'So Widget does not host or sell it. Use it as your personal wallpaper only — no resale, prints or redistribution.',
              children: [
                RowItem(
                  icon: CupertinoIcons.flag_fill,
                  iconColor: K.red,
                  title: 'Report a copyright issue',
                  subtitle: 'Opens this wallpaper on Wallhaven, where owners can request removal',
                  onTap: () => openUrl(w.url),
                ),
              ],
            ),
          ]);
        },
      );
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: K.label2, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
      );
}
