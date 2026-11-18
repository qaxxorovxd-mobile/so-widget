import 'dart:io';

import 'package:flutter/services.dart';

import 'state.dart';

/// Real phone data from Android (SoDevices.kt): memory, storage, battery temperature, steps,
/// and paired Bluetooth devices.
class DeviceApi {
  static const _ch = MethodChannel('so_widget/device');

  static Future<Map<String, dynamic>> stats() async =>
      Map<String, dynamic>.from(await _ch.invokeMapMethod<String, dynamic>('stats') ?? {});

  static Future<Map<String, dynamic>> bluetooth() async =>
      Map<String, dynamic>.from(await _ch.invokeMapMethod<String, dynamic>('bluetooth') ?? {});

  /// Connects or disconnects a paired device (opens Bluetooth settings where the phone requires it).
  static Future<void> btToggle(String address) => _ch.invokeMethod('btToggle', {'address': address});
}

/// Cached device stats, refreshed every minute while visible. Null off Android.
Map<String, dynamic>? deviceStats() {
  if (!Platform.isAndroid) return null;
  app.hub.ensure('device', const Duration(minutes: 1), DeviceApi.stats);
  return app.hub.get<Map<String, dynamic>>('device');
}

/// Steps today from the phone's step counter, or null when unavailable / not permitted.
int? deviceSteps() {
  final s = deviceStats()?['steps'];
  return s is num && s >= 0 ? s.toInt() : null;
}

String gbText(num bytes) {
  final g = bytes / 1e9;
  return g >= 100 ? '${g.round()} GB' : '${g.toStringAsFixed(1)} GB';
}
