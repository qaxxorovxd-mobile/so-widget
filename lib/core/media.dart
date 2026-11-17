import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaSnapshot {
  const MediaSnapshot({this.allowed = false, this.title = '', this.artist = '',
    this.playing = false, this.position = 0, this.duration = 0, this.actions = 0});
  final bool allowed, playing;
  final String title, artist;
  final int position, duration, actions;
  bool get hasTrack => allowed && title.isNotEmpty;
  double get progress => duration > 0 ? (position / duration).clamp(0, 1) : 0;
  bool can(int action) => actions & action != 0;
  factory MediaSnapshot.fromMap(Map<dynamic, dynamic> value) => MediaSnapshot(
    allowed: value['allowed'] == true, playing: value['playing'] == true,
    title: value['title'] as String? ?? '', artist: value['artist'] as String? ?? '',
    position: (value['position'] as num? ?? 0).toInt(), duration: (value['duration'] as num? ?? 0).toInt(),
    actions: (value['actions'] as num? ?? 0).toInt());
}

class MediaState extends ChangeNotifier {
  static const channel = MethodChannel('so_widget/media');
  bool get supported => Platform.isAndroid;
  MediaSnapshot value = const MediaSnapshot();
  ui.Image? artwork;
  Uint8List? _bytes;
  Future<void>? _pending;
  Timer? _timer;
  String? error;

  void start() {
    if (!supported) return;
    channel.setMethodCallHandler((call) async { if (call.method == 'changed') await refresh(); });
    resume();
  }
  void resume() {
    if (!supported) return;
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }
  void pause() { _timer?.cancel(); _timer = null; }

  Future<void> refresh() {
    if (!supported) return Future.value();
    return _pending ??= _read().whenComplete(() => _pending = null);
  }
  Future<void> _read() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('snapshot') ?? {};
      value = MediaSnapshot.fromMap(data);
      final bytes = data['artwork'] as Uint8List?;
      if (!listEquals(bytes, _bytes)) {
        _bytes = bytes;
        final previous = artwork;
        artwork = null;
        if (bytes != null) {
          final codec = await ui.instantiateImageCodec(bytes);
          artwork = (await codec.getNextFrame()).image;
          codec.dispose();
        }
        // Existing frames may still reference the old artwork until the next frame.
        if (previous != null) Timer(const Duration(seconds: 1), previous.dispose);
      }
      error = null;
    } catch (_) { error = 'Unable to read media. Check notification access.'; }
    notifyListeners();
  }
  Future<void> requestAccess() async {
    try { await channel.invokeMethod<void>('permission'); } catch (_) { error = 'Unable to open notification access settings.'; notifyListeners(); }
  }
  Future<void> control(String action) async {
    try { await channel.invokeMethod<void>('control', {'action': action}); await refresh(); }
    catch (_) { error = 'The media app could not perform that action.'; notifyListeners(); }
  }
}

final media = MediaState();
