# So Widget

Premium home-screen widgets in an Apple-inspired style. 56 widgets in 6 collections, one place to style them all.
Designed & developed by **[qaxxorov.uz](https://qaxxorov.uz)**.

## Run

```bash
flutter pub get
flutter run
```

Release APK: `flutter build apk --release --split-per-abi` → `build/app/outputs/flutter-apk/`

## How it works

- **Widgets tab**: browse 56 widgets by collection (Essential, Media, Productivity, Digital Life, Lifestyle, Creative & Smart), search, open one to edit its data, preview it at every size, and tap **Add widget**.
- **Studio tab**: 10 themes, main color, iOS-like fonts (Inter, Geist, Figtree, Nunito as SF Rounded, Newsreader as New York, Geist Mono as SF Mono…), font weight, text size, glow, corner radius, background opacity (glass), and an outline line shared by every widget. **Apply to all widgets** pushes the style to every widget on the home screen in one tap.
- **Info tab**: app info, developer card (qaxxorov.uz), permissions, data sources, reset.

### Home screen (Android)

- Every placed widget is its own instance and shows its own So Widget.
- **Any size**: resize a widget on the home screen (long-press → drag the edges). It adapts automatically:
  1 row (2×1, 3×1, 4×1) shows a one-line glance, 2×2 / 2×3 / 3×2 use the compact layout, 4×2 / 4×3 the wide layout,
  4×4 the large layout. Images are drawn at the exact cell size so all widgets line up.
- Flutter widgets are rendered to images (`home_widget`) with the Skia renderer, which can draw while the app is in the
  background. A JobScheduler job refreshes weather, internet speed and the rest about every 5 minutes.
- Media widgets (Now Playing + the 6 Media designs) are drawn natively in Kotlin and update instantly from the
  Android media session, with working ⏮ ⏯ ⏭ buttons.

iOS home-screen widgets require a WidgetKit extension created in Xcode on macOS (not included).

## Structure

```
lib/
  core/      state, api, registry (render plans + one-row glances), home_sync, media, permissions
  ui/        widget kit, forms, style editor, theme studio, location
  widgets/   essential, productivity, digital, lifestyle, creative, media
  screens/   gallery, detail, studio, info, permissions, picker, root
android/app/src/main/kotlin/uz/qaxxorov/so_widget/
  SoWidgets.kt        providers, per-instance images, sizes channel
  SoNowPlaying.kt     native media widgets (7 designs, any size)
  SoMedia.kt          media session reader (notification listener)
  SoRefreshJob.kt     5-minute background refresh (headless Flutter engine)
  SoConfigActivity.kt native widget picker
```

## Tests

```bash
flutter test test/widgets_test.dart
```

Renders all 56 widgets at 12 home-screen sizes (1×1 … 4×4), with normal and heavy styles (large text, bold, glass,
thick outline), and fails on any layout overflow. `test/showcase_test.dart` writes contact-sheet PNGs to
`test/showcase/` for visual review.
