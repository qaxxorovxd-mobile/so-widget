import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Ambient sounds synthesized on-device — no bundled audio files needed.
class Soundscape extends ChangeNotifier {
  static const sounds = ['Rain', 'Fireplace', 'Ocean', 'Wind', 'Brown noise', 'White noise'];

  AudioPlayer? _p;
  AudioPlayer get _player => _p ??= AudioPlayer();
  String? playing;
  bool loading = false;
  double volume = 0.7;
  DateTime? since;

  Future<void> toggle(String name) async {
    if (playing == name) return stop();
    loading = true;
    playing = name;
    notifyListeners();
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/so_${name.replaceAll(' ', '_').toLowerCase()}.wav');
      if (!await f.exists()) {
        final bytes = await compute(_generate, name);
        await f.writeAsBytes(bytes);
      }
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);
      await _player.play(DeviceFileSource(f.path));
      since = DateTime.now();
    } catch (_) {
      playing = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _p?.stop();
    playing = null;
    since = null;
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v;
    notifyListeners();
    await _p?.setVolume(v);
  }
}

final soundscape = Soundscape();

Uint8List _generate(String name) {
  const rate = 22050;
  const secs = 16;
  const fade = rate; // 1s crossfade for a seamless loop
  final n = rate * secs;
  final buf = Float64List(n + fade);
  final r = math.Random(7);
  double white() => r.nextDouble() * 2 - 1;

  var brown = 0.0;
  double nextBrown() {
    brown = (brown + white() * 0.02) * 0.998;
    return brown * 3.2;
  }

  // pink (Paul Kellet)
  var b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;
  double pink() {
    final w = white();
    b0 = 0.99886 * b0 + w * 0.0555179;
    b1 = 0.99332 * b1 + w * 0.0750759;
    b2 = 0.96900 * b2 + w * 0.1538520;
    b3 = 0.86650 * b3 + w * 0.3104856;
    b4 = 0.55000 * b4 + w * 0.5329522;
    b5 = -0.7616 * b5 - w * 0.0168980;
    final out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362;
    b6 = w * 0.115926;
    return out * 0.11;
  }

  var crackle = 0.0;
  var lp = 0.0;
  for (var i = 0; i < n + fade; i++) {
    final t = i / rate;
    double s;
    switch (name) {
      case 'Rain':
        s = pink() * 0.9;
        if (r.nextDouble() < 0.0025) crackle = white() * 0.6;
        crackle *= 0.93;
        s += crackle;
      case 'Fireplace':
        s = nextBrown() * 0.5;
        if (r.nextDouble() < 0.0009) crackle = (r.nextBool() ? 1 : -1) * (0.5 + r.nextDouble() * 0.5);
        crackle *= 0.86;
        final hp = crackle - lp;
        lp = lp * 0.6 + crackle * 0.4;
        s += hp * 0.9;
      case 'Ocean':
        final swell = 0.35 + 0.65 * math.pow(math.sin(math.pi * t / 8), 2);
        s = (nextBrown() * 0.6 + pink() * 0.4) * swell;
      case 'Wind':
        final gust = 0.45 + 0.35 * math.sin(2 * math.pi * t / 16) + 0.2 * math.sin(2 * math.pi * t / 4);
        lp = lp * 0.97 + pink() * 0.03;
        s = (lp * 9 + nextBrown() * 0.3) * gust;
      case 'White noise':
        s = white() * 0.35;
      default:
        s = nextBrown() * 0.8;
    }
    buf[i] = s;
  }
  // crossfade tail into head
  for (var i = 0; i < fade; i++) {
    final a = i / fade;
    buf[i] = buf[i] * a + buf[n + i] * (1 - a);
  }
  var peak = 0.0;
  for (var i = 0; i < n; i++) {
    peak = math.max(peak, buf[i].abs());
  }
  final gain = peak == 0 ? 1.0 : 0.85 / peak;

  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var k = 0; k < s.length; k++) {
      data.setUint8(o + k, s.codeUnitAt(k));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (buf[i] * gain * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}
