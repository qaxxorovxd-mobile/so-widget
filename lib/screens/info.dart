import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/permissions.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../ui/forms.dart';
import 'permissions.dart';
import '../widgets/productivity.dart' show openUrl;

const kVersion = '1.2.0';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.only(top: top + 30, bottom: 40),
      children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset('assets/logo.webp', fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'So Widget',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: K.label,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Version $kVersion',
            style: TextStyle(fontSize: 14, color: K.label2),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Premium widgets for people who never stop customizing their home screen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: K.label2, height: 1.4),
          ),
        ),
        const SizedBox(height: 28),
        const _DeveloperCard(),
        ListenableBuilder(
          listenable: perms,
          builder: (context, _) => Section(
            children: [
              RowItem(
                icon: CupertinoIcons.checkmark_shield_fill,
                iconColor: perms.allGranted ? K.green : const Color(0xFFFF9F0A),
                title: 'Permissions',
                value: perms.allGranted ? 'All set' : '${perms.missing} missing',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PermissionsPage()),
                ),
              ),
            ],
          ),
        ),
        Section(
          title: 'About',
          children: [
            RowItem(
              icon: CupertinoIcons.square_grid_2x2_fill,
              iconColor: K.blue,
              title: 'Widgets',
              value: '${allWidgets.length}',
            ),
            RowItem(
              icon: CupertinoIcons.folder_fill,
              iconColor: const Color(0xFFFF9F0A),
              title: 'Collections',
              value: '${WCat.values.length}',
            ),
            const RowItem(
              icon: CupertinoIcons.lock_fill,
              iconColor: K.green,
              title: 'Privacy',
              subtitle: 'Your notes, tasks and photos stay on this device.',
            ),
          ],
        ),
        const Section(
          title: 'Data sources',
          footer: 'Free, keyless public APIs. Thank you to every project that keeps them open.',
          children: [
            RowItem(title: 'Weather & air quality', value: 'Open-Meteo'),
            RowItem(title: 'Crypto', value: 'CoinGecko'),
            RowItem(title: 'Currency', value: 'Central Bank of Uzbekistan'),
            RowItem(title: 'Stocks', value: 'Yahoo Finance'),
            RowItem(title: 'Quote of the day', value: 'ZenQuotes'),
            RowItem(title: 'Word of the day', value: 'Merriam-Webster'),
            RowItem(title: 'Releases', value: 'GitHub'),
            RowItem(title: 'Prayer times', value: 'Aladhan'),
            RowItem(title: 'Earthquakes', value: 'USGS'),
            RowItem(title: 'ISS position', value: 'WhereTheISS'),
            RowItem(title: 'News', value: 'Hacker News'),
            RowItem(title: 'Translation', value: 'MyMemory'),
            RowItem(title: 'Wallpaper library', value: 'Wallhaven'),
            RowItem(title: 'Photo widget samples', value: 'Lorem Picsum'),
          ],
        ),
        Section(
          title: 'Wallpapers by Wallhaven',
          footer: 'Wallpapers are shared by the Wallhaven community and stay the property of their creators. '
              'So Widget is not affiliated with Wallhaven, does not host the images, and shows only safe-for-work content. '
              'Every wallpaper keeps its uploader, source and a link back. Use them as personal wallpapers only.',
          children: [
            for (final (icon, title, path) in const [
              (CupertinoIcons.globe, 'Wallhaven', ''),
              (CupertinoIcons.chevron_left_slash_chevron_right, 'API documentation', '/help/api'),
              (CupertinoIcons.doc_text_fill, 'Terms of Service', '/terms'),
              (CupertinoIcons.hand_raised_fill, 'Privacy Policy', '/privacy'),
              (CupertinoIcons.shield_lefthalf_fill, 'Copyright & DMCA', '/dmca'),
              (CupertinoIcons.list_bullet, 'Upload rules', '/help/rules'),
            ])
              RowItem(
                icon: icon,
                iconColor: const Color(0xFF3A3A3C),
                title: title,
                value: path.isEmpty ? 'wallhaven.cc' : null,
                onTap: () => openUrl('https://wallhaven.cc$path'),
              ),
          ],
        ),
        Section(
          children: [
            RowItem(
              title: 'Reset all widget data',
              destructive: true,
              onTap: () async {
                if (!await confirm(
                  context,
                  'Reset everything?',
                  'Tasks, notes, habits and all widget data will be erased. Styles are kept.',
                  action: 'Reset',
                )) {
                  return;
                }
                await app.resetAll();
                seedAll(app.store);
                if (context.mounted) toast(context, 'Data reset');
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => openUrl('https://qaxxorov.uz'),
            child: const Text(
              'Crafted with care by qaxxorov.uz',
              style: TextStyle(fontSize: 13, color: K.label3),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
    child: GestureDetector(
      onTap: () {
        tapFeedback();
        openUrl('https://qaxxorov.uz');
      },
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEVELOPER',
                    style: TextStyle(
                      fontSize: 12,
                      color: K.label2,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'qaxxorov.uz',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Designed & developed So Widget',
                    style: TextStyle(fontSize: 14, color: K.label2),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.arrow_up_right,
                color: Colors.black,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
