import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_widget/core/registry.dart';
import 'package:so_widget/core/state.dart';
import 'package:so_widget/core/style.dart';
import 'package:so_widget/screens/detail.dart';
import 'package:so_widget/screens/gallery.dart';
import 'package:so_widget/screens/info.dart';
import 'package:so_widget/screens/picker.dart';
import 'package:so_widget/screens/studio.dart';
import 'package:so_widget/screens/wallpapers.dart';
import 'package:so_widget/ui/forms.dart';
import 'package:so_widget/ui/kit.dart';
import 'package:so_widget/ui/style_editor.dart';

import 'widgets_test.dart' as base;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    useGoogleFonts = false;
    final font = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('TestSans')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
      fallbackFontFamily = 'TestSans';
    }
    final icons = File(
      '${Platform.environment['LOCALAPPDATA']}/Pub/Cache/hosted/pub.dev/cupertino_icons-1.0.9/assets/CupertinoIcons.ttf',
    );
    if (icons.existsSync()) {
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
    await app.init();
    seedAll(app.store);
    base.fakeData();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: fallbackFontFamily,
          ),
          cupertinoOverrideTheme: CupertinoThemeData(
            brightness: Brightness.dark,
            textTheme: CupertinoTextThemeData(
              textStyle: TextStyle(fontFamily: fallbackFontFamily),
            ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  }

  test('customization survives storage and old styles keep defaults', () {
    final custom = WStyle.graphite.copyWith(
      textScale: 0.8,
      compact: true,
      border: false,
      textGlow: true,
    );
    expect(WStyle.fromJson(custom.toJson()).sameAs(custom), isTrue);
    final old = WStyle.fromJson({'bg': 0xFF141414, 'font': 'Inter'});
    expect(old.textScale, 1);
    expect(old.compact, isFalse);
    expect(old.border, isTrue);
    expect(old.textGlow, isFalse);
    app.settings.setOverride('chrono', custom);
    app.settings.load();
    expect(app.settings.styleFor('chrono').sameAs(custom), isTrue);
    app.settings.setOverride('chrono', null);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('screens fit $size at text scale $scale', (tester) async {
        for (final page in [
          const GalleryPage(),
          const StudioPage(),
          const InfoPage(),
          const WallpapersPage(active: false),
          DetailPage(allWidgets.first),
        ]) {
          await mount(tester, page, size, textScale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} at $size',
          );
          final scroll = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scroll, const Offset(0, -450));
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${page.runtimeType}, scroll $i',
            );
          }
          await clean(tester);
        }
      });
    }
  }

  testWidgets('all widget editors fit a small phone', (tester) async {
    for (final def in allWidgets) {
      await mount(tester, DetailPage(def), const Size(320, 568));
      final scroll = find.byType(Scrollable).first;
      for (var i = 0; i < 5; i++) {
        await tester.drag(scroll, const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${def.id} editor');
      }
      await clean(tester);
    }
  });

  testWidgets(
    'picker searches and confirms without immediately changing selection',
    (tester) async {
      WDef? result;
      await mount(
        tester,
        Builder(
          builder: (context) => PillButton(
            'Open',
            onTap: () async {
              result = await pickWidget(
                context,
                WSize.small,
                current: 'chrono',
              );
            },
          ),
        ),
        const Size(320, 568),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'github');
      await tester.pumpAndSettle();
      final row = find.byType(RowItem);
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(result, isNull);
      await tester.tap(find.text('Use widget'));
      await tester.pumpAndSettle();
      expect(result?.id, 'github');
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  testWidgets(
    'style draft cancels, applies, copies and restores Studio style',
    (tester) async {
      app.settings.setOverride('chrono', null);
      await mount(
        tester,
        DetailPage(widgetById['chrono']!),
        const Size(320, 568),
      );
      Future<void> openStyle() async {
        await tester.ensureVisible(find.text('Style'));
        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();
      }

      await openStyle();
      tester
          .widget<StyleEditor>(find.byType(StyleEditor))
          .onChanged(WStyle.graphite.copyWith(textScale: 0.8));
      await tester.pump();
      expect(app.settings.hasOverride('chrono'), isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.settings.hasOverride('chrono'), isFalse);
      await openStyle();
      tester
          .widget<StyleEditor>(find.byType(StyleEditor))
          .onChanged(WStyle.graphite.copyWith(textScale: 0.8, compact: true));
      await tester.pump();
      await tester.tap(find.text('Apply style'));
      await tester.pumpAndSettle();
      expect(app.settings.styleFor('chrono').textScale, 0.8);
      expect(app.settings.styleFor('chrono').compact, isTrue);
      await openStyle();
      await tester.tap(find.text('Copy style from widget'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'github');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RowItem).last);
      await tester.pump();
      await tester.tap(find.text('Use widget'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StyleEditor>(find.byType(StyleEditor))
            .style
            .sameAs(app.settings.styleFor('github')),
        isTrue,
      );
      tester
          .widget<SwitchRow>(find.widgetWithText(SwitchRow, 'Use Studio style'))
          .onChanged(true);
      await tester.pump();
      await tester.tap(find.text('Apply style'));
      await tester.pumpAndSettle();
      expect(app.settings.hasOverride('chrono'), isFalse);
      expect(tester.takeException(), isNull);
      await clean(tester);
    },
  );

  testWidgets('customized faces fit all sizes', (tester) async {
    for (final def in allWidgets) {
      for (final size in WSize.values) {
        await mount(
          tester,
          Center(
            child: WidgetFace(
              def,
              size,
              live: false,
              style: WStyle.graphite.copyWith(
                textScale: 0.8,
                compact: true,
                border: false,
                textGlow: true,
              ),
            ),
          ),
          const Size(430, 932),
          textScale: 1.6,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${def.id} ${size.name}',
        );
      }
    }
    await clean(tester);
  });

  testWidgets('picker and color sheet fit above the keyboard', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    await mount(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            PillButton(
              'Pick',
              onTap: () => pickWidget(context, WSize.large, current: 'chrono'),
            ),
            PillButton(
              'Color',
              onTap: () => showSheet(
                context,
                ColorPicker(initial: Colors.white, onChanged: (_) {}),
                title: 'Background',
              ),
            ),
          ],
        ),
      ),
      const Size(320, 568),
      textScale: 1.6,
    );
    for (final label in ['Pick', 'Color']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label with keyboard');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(EditableText))).pop();
      await tester.pumpAndSettle();
    }
    await clean(tester);
  });

  if (Platform.environment['SO_UI_PREVIEWS'] == '1') {
    testWidgets('render responsive UI previews', (tester) async {
      await mount(tester, const GalleryPage(), const Size(390, 844));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../.dart_tool/ui-preview/gallery.png'),
      );
      await clean(tester);
      await mount(
        tester,
        DetailPage(widgetById['chrono']!),
        const Size(320, 568),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../.dart_tool/ui-preview/detail.png'),
      );
      await tester.ensureVisible(find.text('Style'));
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../.dart_tool/ui-preview/style.png'),
      );
      await tester.tap(find.text('Copy style from widget'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../.dart_tool/ui-preview/picker.png'),
      );
      await clean(tester);
    });
  }
}
