@Tags(['showcase'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_widget/core/registry.dart';
import 'package:so_widget/core/state.dart';
import 'package:so_widget/core/style.dart';
import 'package:so_widget/ui/kit.dart';

import 'widgets_test.dart' as base;

/// Renders a contact sheet of widgets to test/showcase/*.png for visual review.
/// Run: flutter test test/showcase_test.dart --update-goldens
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    useGoogleFonts = false;
    final loader = FontLoader('TestSans');
    for (final f in [r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\seguisb.ttf', r'C:\Windows\Fonts\segoeuib.ttf']) {
      if (File(f).existsSync()) loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
    final icons = File('${Platform.environment['LOCALAPPDATA']}/Pub/Cache/hosted/pub.dev/cupertino_icons-1.0.9/assets/CupertinoIcons.ttf');
    if (icons.existsSync()) {
      final l = FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await l.load();
    }
    fallbackFontFamily = 'TestSans';
    await app.init();
    seedAll(app.store);
    base.fakeData();
  });

  for (final cat in WCat.values) {
    testWidgets('showcase ${cat.name}', (tester) async {
      final defs = allWidgets.where((w) => w.cat == cat).toList();
      tester.view.physicalSize = const Size(1640, 2100);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xFF2A2A2E),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(spacing: 20, runSpacing: 20, children: [
              for (final d in defs) ...[
                WidgetFace(d, WSize.small, live: false),
                WidgetFace(d, WSize.medium, live: false),
              ],
            ]),
          ),
        ),
      ));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('showcase/${cat.name}.png'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 3));
    });
  }

  testWidgets('showcase large', (tester) async {
    tester.view.physicalSize = const Size(1600, 1640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF2A2A2E),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(spacing: 20, runSpacing: 20, children: [
            for (final id in ['chrono', 'power', 'forecast', 'calendar', 'focus', 'prayer', 'github', 'atmosphere'])
              WidgetFace(widgetById[id]!, WSize.large, live: false),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('showcase/large.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  });
}
