import 'dart:async';
import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../core/home_sync.dart';
import '../core/media.dart';
import '../core/permissions.dart';
import '../ui/forms.dart';
import '../widgets/productivity.dart' show captureClipboard;
import 'detail.dart';
import 'gallery.dart';
import 'info.dart';
import 'permissions.dart';
import 'studio.dart';

final soNavKey = GlobalKey<NavigatorState>();

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      captureClipboard();
      HomeSync.schedule(const Duration(seconds: 2));
    });
    if (HomeSync.supported) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        _handle(uri);
        // Ask for permissions on a normal launch (not the quick render hand-off from the picker).
        if (uri?.host != 'render') _askPermissions();
      }).catchError((_) => _askPermissions());
      _sub = HomeWidget.widgetClicked.listen(_handle, onError: (_) {});
    }
  }

  void _askPermissions() => WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = soNavKey.currentState;
        if (nav != null) PermissionsPage.maybeShow(nav);
      });

  StreamSubscription<Uri?>? _sub;

  void _handle(Uri? uri) {
    if (uri?.host == 'permissions') {
      soNavKey.currentState?.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PermissionsPage()));
      return;
    }
    _open(uri);
  }

  void _open(Uri? uri) => HomeSync.handleUri(
    uri,
    soNavKey,
    (def, wid) => DetailPage(def, homeWid: wid),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      media.resume();
      perms.refresh();
      captureClipboard();
      HomeSync.schedule(const Duration(seconds: 1));
    } else if (state == AppLifecycleState.paused) {
      media.pause();
      HomeSync.syncAll();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: K.bg,
    body: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: IndexedStack(
            index: _tab,
            children: const [GalleryPage(), StudioPage(), InfoPage()],
          ),
        ),
      ),
    ),
    bottomNavigationBar: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: CupertinoTabBar(
          backgroundColor: const Color(0xCC0A0A0A),
          activeColor: Colors.white,
          inactiveColor: K.label3,
          border: const Border(top: BorderSide(color: K.sep, width: 0.5)),
          currentIndex: _tab,
          onTap: (i) {
            tapFeedback();
            setState(() => _tab = i);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: 'Widgets',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.paintbrush_fill),
              label: 'Studio',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.info_circle_fill),
              label: 'Info',
            ),
          ],
        ),
      ),
    ),
  );
}
