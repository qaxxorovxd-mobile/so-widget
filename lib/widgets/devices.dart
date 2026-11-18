import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/device.dart';
import '../core/permissions.dart';
import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import 'media.dart' show MediaFace;

/// Device manager widgets. On Android they are drawn natively (SoDevices.kt) with live data and
/// tap areas; the app shows the same native drawing as previews.
final devicesWidgets = <WDef>[
  _def(57, 'd_bluetooth', 'Bluetooth', 'Paired devices with battery levels. Tap a device to connect or disconnect in one tap.',
      CupertinoIcons.bluetooth, const _BluetoothEditor()),
  _def(58, 'd_controls', 'Controls', 'Wi-Fi, Bluetooth, flashlight, sound mode, mobile data, battery saver, location, Focus and hotspot.',
      CupertinoIcons.square_grid_2x2_fill, const _ControlsEditor(), preferred: WSize.medium),
  _def(59, 'd_batteries', 'Batteries', 'Your phone and connected earbuds, watch or speaker, like the iPhone batteries widget.',
      CupertinoIcons.battery_full, const _InfoEditor('Shows every connected Bluetooth device that reports its battery level. Updates the moment a device connects or its level changes.')),
  _def(60, 'd_storage', 'Storage', 'Real free space and memory on this phone, with temperature and uptime.',
      CupertinoIcons.archivebox_fill, const _InfoEditor('Read directly from Android. Tap the widget to open storage settings.'), preferred: WSize.medium),
];

WDef _def(int no, String id, String name, String desc, IconData icon, Widget editor, {WSize preferred = WSize.small}) => WDef(
      no: no,
      id: id,
      name: name,
      desc: desc,
      cat: WCat.devices,
      icon: icon,
      preferred: preferred,
      face: (c) => MediaFace(id, c, fallback: (c) => _fallback(c, id, name, icon)),
      editor: (ctx) => editor,
    );

/// Flutter face where native drawing isn't available (iOS, tests).
Widget _fallback(WCtx c, String id, String name, IconData icon) {
  final g = devicesGlances[id]!(c);
  return WShell(
    c: c,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, icon, name),
      const Spacer(),
      Icon(g.icon ?? icon, size: c.sm ? 28 : 34, color: c.fg, shadows: c.glowFor(c.fg)),
      const SizedBox(height: 8),
      Text(g.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 16 : 19)),
      Text(g.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.sm ? 12 : 14, dim: true)),
    ]),
  );
}

Map<String, dynamic>? _bt() {
  if (!Platform.isAndroid) return null;
  app.hub.ensure('bt', const Duration(seconds: 30), DeviceApi.bluetooth);
  return app.hub.get<Map<String, dynamic>>('bt');
}

List<Map<String, dynamic>> _btDevices() =>
    ((_bt()?['devices'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

final devicesGlances = <String, Glance Function(WCtx)>{
  'd_bluetooth': (c) {
    final b = _bt();
    if (b == null) return const Glance('Bluetooth', label: 'Paired devices', icon: CupertinoIcons.bluetooth);
    if (b['permitted'] != true) return const Glance('Allow Bluetooth', label: 'Tap to give access', icon: CupertinoIcons.bluetooth);
    if (b['enabled'] != true) return const Glance('Bluetooth off', label: 'Tap to turn on', icon: CupertinoIcons.bluetooth);
    final list = _btDevices();
    final on = list.where((d) => d['connected'] == true).toList();
    if (on.isEmpty) return Glance('Not connected', label: '${list.length} paired devices', icon: CupertinoIcons.bluetooth);
    final bat = (on.first['battery'] as num? ?? -1).toInt();
    return Glance('${on.first['name']}', label: bat >= 0 ? 'Connected · $bat%' : 'Connected', icon: CupertinoIcons.headphones,
        progress: bat >= 0 ? bat / 100 : null, color: c.pos);
  },
  'd_controls': (c) => const Glance('Controls', label: 'Wi-Fi · Bluetooth · Flashlight · Sound', icon: CupertinoIcons.square_grid_2x2_fill),
  'd_batteries': (c) {
    final list = _btDevices().where((d) => d['connected'] == true && (d['battery'] as num? ?? -1) >= 0).toList();
    return Glance('${app.power.level}%', label: list.isEmpty ? 'This phone' : list.map((d) => '${d['name']} ${d['battery']}%').join(' · '),
        icon: CupertinoIcons.battery_full, progress: app.power.level / 100);
  },
  'd_storage': (c) {
    final d = deviceStats();
    final t = (d?['storageTotal'] as num?)?.toDouble() ?? 0, f = (d?['storageFree'] as num?)?.toDouble() ?? 0;
    if (t <= 0) return const Glance('Storage', label: 'Reading your phone…', icon: CupertinoIcons.archivebox_fill);
    return Glance('${gbText(f)} free', label: 'of ${gbText(t)}', icon: CupertinoIcons.archivebox_fill, progress: 1 - f / t);
  },
};

/// Live paired-device list with one-tap connect, inside the app.
class _BluetoothEditor extends StatefulWidget {
  const _BluetoothEditor();

  @override
  State<_BluetoothEditor> createState() => _BluetoothEditorState();
}

class _BluetoothEditorState extends State<_BluetoothEditor> {
  Map<String, dynamic>? _b;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!Platform.isAndroid) return;
    try {
      final b = await DeviceApi.bluetooth();
      if (mounted) setState(() => _b = b);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Section(title: 'Devices', children: [RowItem(title: 'Bluetooth widgets work on Android')]);
    }
    final b = _b;
    final devices = ((b?['devices'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Section(
      title: 'Paired devices',
      footer: 'Tap a device to connect or disconnect. Some phones only allow this inside Bluetooth settings; '
          'then So Widget opens them for you.',
      children: [
        if (b != null && b['permitted'] != true)
          RowItem(
            icon: CupertinoIcons.bluetooth,
            iconColor: K.blue,
            title: 'Allow Bluetooth access',
            subtitle: 'Needed to list and connect your devices',
            onTap: () async {
              await perms.request('bluetooth');
              Timer(const Duration(seconds: 2), _load);
            },
          )
        else if (b != null && b['enabled'] != true)
          RowItem(
            icon: CupertinoIcons.bluetooth,
            iconColor: K.blue,
            title: 'Bluetooth is off',
            subtitle: 'Tap to turn it on',
            onTap: () => DeviceApi.btToggle('power'),
          ),
        for (final d in devices)
          RowItem(
            icon: d['connected'] == true ? CupertinoIcons.checkmark_alt : CupertinoIcons.bluetooth,
            iconColor: d['connected'] == true ? K.green : const Color(0xFF3A3A3C),
            title: '${d['name']}',
            subtitle: d['connected'] == true
                ? 'Connected${(d['battery'] as num? ?? -1) >= 0 ? ' · ${d['battery']}% battery' : ''}'
                : 'Tap to connect',
            value: d['connected'] == true ? 'Disconnect' : 'Connect',
            onTap: () async {
              await DeviceApi.btToggle('${d['address']}');
              Timer(const Duration(seconds: 3), _load);
            },
          ),
        if (b != null && b['enabled'] == true && devices.isEmpty)
          const RowItem(title: 'No paired devices', subtitle: 'Pair a device in Bluetooth settings first'),
      ],
    );
  }
}

class _ControlsEditor extends StatelessWidget {
  const _ControlsEditor();

  @override
  Widget build(BuildContext context) => const Section(
        title: 'How it works',
        footer: 'Flashlight and sound mode switch right on the widget. Wi-Fi, mobile data, Bluetooth, location, Focus '
            'and hotspot open Android’s quick panel, because Android doesn’t let apps flip them directly. '
            'Resize the widget to show 4, 6 or 9 controls.',
        children: [
          RowItem(icon: CupertinoIcons.lightbulb_fill, iconColor: Color(0xFFFF9F0A), title: 'Flashlight', value: 'Toggles'),
          RowItem(icon: CupertinoIcons.speaker_3_fill, iconColor: Color(0xFF5E5CE6), title: 'Sound', value: 'Ring ↔ Vibrate'),
          RowItem(icon: CupertinoIcons.wifi, iconColor: K.blue, title: 'Wi-Fi', value: 'Quick panel'),
          RowItem(icon: CupertinoIcons.antenna_radiowaves_left_right, iconColor: K.green, title: 'Mobile data', value: 'Quick panel'),
        ],
      );
}

class _InfoEditor extends StatelessWidget {
  const _InfoEditor(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Section(
        title: 'Live data',
        footer: text,
        children: [
          RowItem(
            icon: CupertinoIcons.checkmark_shield_fill,
            iconColor: K.green,
            title: 'Permissions',
            subtitle: 'Bluetooth access lets it see your devices',
            onTap: () => perms.request('bluetooth'),
          ),
        ],
      );
}

/// Keeps Cupertino glyphs used only by native widgets in the icon font.
const kNativeGlyphs = [
  CupertinoIcons.bluetooth, CupertinoIcons.headphones, CupertinoIcons.speaker_3_fill, CupertinoIcons.car_detailed,
  CupertinoIcons.clock_fill, CupertinoIcons.device_phone_portrait, CupertinoIcons.device_laptop, CupertinoIcons.keyboard,
  CupertinoIcons.gamecontroller_fill, CupertinoIcons.printer_fill, CupertinoIcons.tv_fill, CupertinoIcons.wifi,
  CupertinoIcons.wifi_slash, CupertinoIcons.lightbulb_fill, CupertinoIcons.lightbulb_slash_fill, CupertinoIcons.waveform,
  CupertinoIcons.speaker_slash_fill, CupertinoIcons.antenna_radiowaves_left_right, CupertinoIcons.leaf_arrow_circlepath,
  CupertinoIcons.location_fill, CupertinoIcons.location_slash_fill, CupertinoIcons.moon_fill, CupertinoIcons.personalhotspot,
  CupertinoIcons.bolt_fill, CupertinoIcons.battery_100, CupertinoIcons.archivebox_fill, CupertinoIcons.cube_fill,
  CupertinoIcons.plus, CupertinoIcons.gear_alt_fill, CupertinoIcons.chevron_left, CupertinoIcons.chevron_right,
];

/// Referenced so the tree shaker keeps [kNativeGlyphs].
int get nativeGlyphCount => kNativeGlyphs.length;
