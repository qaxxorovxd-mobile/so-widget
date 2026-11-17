import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/home_sync.dart';
import 'core/registry.dart';
import 'core/state.dart';
import 'core/media.dart';
import 'screens/root.dart';
import 'ui/forms.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  seedAll(app.store);
  media.start();
  HomeSync.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SoApp());
}

/// Entry point for the headless engine started by SoRefreshJob every ~5 minutes.
/// Refreshes weather, network speed, media and everything else shown on the home screen.
@pragma('vm:entry-point')
Future<void> widgetRefreshMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const done = MethodChannel('so_widget/background');
  var ok = false;
  try {
    await app.init();
    seedAll(app.store);
    await media.refresh();
    ok = await HomeSync.backgroundRefresh();
    app.store.flush();
  } catch (e) {
    debugPrint('widgetRefreshMain: $e');
  }
  try {
    await done.invokeMethod('complete', {'success': ok});
  } catch (_) {}
}

class SoApp extends StatelessWidget {
  const SoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return MaterialApp(
      title: 'So Widget',
      navigatorKey: soNavKey,
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: K.bg,
        colorScheme: const ColorScheme.dark(primary: Colors.white, surface: K.card),
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        splashFactory: NoSplash.splashFactory,
        cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark, primaryColor: Colors.white),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }),
      ),
      home: const RootShell(),
    );
  }
}
