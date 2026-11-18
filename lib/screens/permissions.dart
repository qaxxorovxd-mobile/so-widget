import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/media.dart';
import '../core/permissions.dart';
import '../ui/forms.dart';

/// Shown on launch while any permission is missing. Also reachable from Info.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  static bool _shownThisLaunch = false;

  /// Presents the page once per launch if something is still missing.
  static Future<void> maybeShow(NavigatorState nav) async {
    if (_shownThisLaunch || !perms.supported) return;
    await perms.refresh();
    if (!perms.loaded || perms.allGranted) return;
    _shownThisLaunch = true;
    await nav.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PermissionsPage()));
  }

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    perms.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User comes back from a system settings screen.
    if (state == AppLifecycleState.resumed) {
      perms.refresh();
      media.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: K.bg,
      body: ListenableBuilder(
        listenable: perms,
        builder: (context, _) => Column(children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, mq.padding.top + 36, 0, 20),
              children: [
                Center(
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: ShapeDecoration(
                      color: K.card,
                      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(22)),
                      shadows: [BoxShadow(color: Colors.white.withValues(alpha: 0.12), blurRadius: 30)],
                    ),
                    child: const Icon(CupertinoIcons.checkmark_shield_fill, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text('Allow access',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: K.label, letterSpacing: -1)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(36, 8, 36, 28),
                  child: Text(
                    'So Widget needs a few permissions so every widget stays live on your home screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: K.label2, height: 1.35),
                  ),
                ),
                Section(
                  footer: 'Only the playing track, artist, artwork and progress are read. Messages and notification text are never read or stored.',
                  children: [
                    _PermRow(
                      icon: CupertinoIcons.music_note_2,
                      color: const Color(0xFFFF2D55),
                      title: 'Media access',
                      subtitle: 'Shows the song playing in Spotify, YouTube Music and other apps on Now Playing.',
                      granted: perms.media,
                      onTap: () => perms.request('media'),
                    ),
                  ],
                ),
                Section(
                  footer: 'Without this Android may delay updates for hours. Nothing runs when you have no widgets on the home screen.',
                  children: [
                    _PermRow(
                      icon: CupertinoIcons.battery_charging,
                      color: K.green,
                      title: 'Background updates',
                      subtitle: 'Refresh weather, internet speed and media every 5 minutes.',
                      granted: perms.battery,
                      onTap: () => perms.request('battery'),
                    ),
                  ],
                ),
                Section(
                  footer: 'Bluetooth lists your earbuds, watch and speakers with their battery, and connects them in one tap. '
                      'Physical activity lets Fitness Rings read the phone’s real step counter.',
                  children: [
                    _PermRow(
                      icon: CupertinoIcons.bluetooth,
                      color: K.blue,
                      title: 'Bluetooth devices',
                      subtitle: 'Bluetooth, Batteries and Controls widgets.',
                      granted: perms.bluetooth,
                      onTap: () => perms.request('bluetooth'),
                    ),
                    _PermRow(
                      icon: CupertinoIcons.flame_fill,
                      color: const Color(0xFFFF2D55),
                      title: 'Physical activity',
                      subtitle: 'Real steps for Fitness Rings.',
                      granted: perms.activity,
                      onTap: () => perms.request('activity'),
                    ),
                  ],
                ),
                if (perms.hasAutostart)
                  Section(
                    footer: 'Turn on the switch for So Widget on the screen that opens. ${perms.brand} stops apps without it.',
                    children: [
                      _PermRow(
                        icon: CupertinoIcons.restart,
                        color: const Color(0xFFFF9F0A),
                        title: 'Autostart',
                        subtitle: 'Lets widgets keep updating after a restart or when the app is closed.',
                        granted: perms.autostartDone,
                        grantedLabel: 'Opened',
                        onTap: () => perms.request('autostart'),
                      ),
                    ],
                  ),
                Section(
                  footer: 'Photos for Photo Frame are chosen with the system picker. No storage permission needed.',
                  children: [
                    RowItem(
                      icon: CupertinoIcons.gear_alt_fill,
                      iconColor: const Color(0xFF3A3A3C),
                      title: 'App settings',
                      subtitle: 'Battery “Unrestricted”, notifications and more',
                      onTap: () => perms.request('app'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, mq.padding.bottom + 16),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  perms.allGranted ? 'Continue' : 'Continue (${perms.missing} left)',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
    this.grantedLabel = 'Allowed',
  });
  final IconData icon;
  final Color color;
  final String title, subtitle, grantedLabel;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RowItem(
        icon: icon,
        iconColor: color,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: granted
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill, color: K.green, size: 20),
                  const SizedBox(width: 4),
                  Text(grantedLabel, style: const TextStyle(color: K.green, fontSize: 14, fontWeight: FontWeight.w600)),
                ])
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                  child: const Text('Allow', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
        ),
      );
}
