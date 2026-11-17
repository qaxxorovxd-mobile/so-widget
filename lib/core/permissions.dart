import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'state.dart';

/// Tracks the system permissions So Widget needs (Android).
class Perms extends ChangeNotifier {
  static const _ch = MethodChannel('so_widget/permissions');

  bool get supported => Platform.isAndroid;
  bool loaded = false;

  /// Notification access, used only to read the current media session (Now Playing).
  bool media = false;

  /// Exempt from battery optimization so the 5-minute refresh is not delayed.
  bool battery = false;

  /// Phone brand has its own "autostart" switch (Xiaomi, Oppo, Vivo, Huawei…).
  bool hasAutostart = false;
  String brand = '';

  /// Autostart state can't be read, so remember that the user opened it.
  bool get autostartDone => app.store.flag('perm.autostart');

  bool get allGranted => !supported || (media && battery && (!hasAutostart || autostartDone));
  int get missing => [!media, !battery, hasAutostart && !autostartDone].where((e) => e).length;

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('status') ?? {};
      media = m['media'] == true;
      battery = m['battery'] == true;
      hasAutostart = m['autostart'] == true;
      brand = '${m['brand'] ?? ''}';
      loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Perms.refresh: $e');
    }
  }

  Future<void> request(String which) async {
    try {
      await _ch.invokeMethod<bool>(which);
      if (which == 'autostart') app.store.set('perm.autostart', true);
    } catch (e) {
      debugPrint('Perms.request $which: $e');
    }
    notifyListeners();
  }
}

final perms = Perms();
