import 'package:cupertino_ui/cupertino_ui.dart';
import '../core/media.dart';
import 'forms.dart';

class MediaControls extends StatelessWidget {
  const MediaControls({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: media, builder: (context, _) {
    final m = media.value;
    return Section(title: 'Now Playing · live media',
      footer: !media.supported ? 'Other apps’ media is available on Android. Soundscape playback still appears in Now Playing.'
        : !m.allowed ? 'Enable notification access once to read the current media session. So Widget uses track metadata, artwork and playback state; it does not read or store message content.'
        : 'Shows the active media app. The player must publish an Android media session.',
      children: [
        if (media.supported) RowItem(
          title: m.allowed ? 'Media access enabled' : 'Enable media access',
          subtitle: media.error ?? (m.hasTrack ? '${m.title} · ${m.artist}' : 'Play music in your favorite app'),
          icon: CupertinoIcons.music_note_2, iconColor: m.allowed ? K.green : K.card2,
          onTap: media.requestAccess,
        ),
        if (m.hasTrack) Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: PillButton('Previous', filled: false, onTap: m.can(16) ? () => media.control('previous') : null)),
          const SizedBox(width: 8),
          Expanded(child: PillButton(m.playing ? 'Pause' : 'Play',
            onTap: m.can(512) || m.can(m.playing ? 2 : 4) ? () => media.control('toggle') : null)),
          const SizedBox(width: 8),
          Expanded(child: PillButton('Next', filled: false, onTap: m.can(32) ? () => media.control('next') : null)),
        ])),
        if (m.hasTrack) RowItem(title: 'Open media app', icon: CupertinoIcons.arrow_up_right, onTap: () => media.control('open')),
      ]);
  });
}
