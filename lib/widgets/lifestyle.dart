import 'dart:io';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import '../core/media.dart';
import 'media.dart' show MediaFace, mediaGlance;
import '../core/registry.dart';
import '../core/sound.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import '../ui/location.dart';
import '../ui/media_controls.dart';

void seedLifestyle(Store s) {
  s.seed('photos.every', 30);
  s.seed('water.goal', 8);
  s.seed('water.ml', 250);
  s.seed('fit.goals', {'steps': 8000, 'move': 500, 'active': 30});
  s.seed('books', [
    {'t': 'Atomic Habits', 'a': 'James Clear', 'p': 112, 'n': 320},
  ]);
  s.seed('prayer.method', 3);
  s.seed('prayer.school', 1);
}

final lifestyleWidgets = <WDef>[
  WDef(
    no: 31,
    id: 'nowplaying',
    name: 'Now Playing',
    desc: 'Your current media, album artwork and real playback progress.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.music_note_2,
    preferred: WSize.medium,
    face: (c) => ListenableBuilder(
      listenable: Listenable.merge([soundscape, media]),
      builder: (context, _) => soundscape.playing != null && !media.value.hasTrack
          ? _nowPlaying(c)
          : MediaFace('nowplaying', c, fallback: _nowPlaying),
    ),
    editor: (ctx) => const MediaControls(),
  ),
  WDef(
    no: 32,
    id: 'soundscape',
    name: 'Soundscape',
    desc: 'Rain, fireplace, ocean and noise — generated on device.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.cloud_rain_fill,
    face: (c) => ListenableBuilder(listenable: soundscape, builder: (context, _) => _sound(c)),
    editor: (ctx) => const _SoundEditor(),
  ),
  WDef(
    no: 33,
    id: 'photos',
    name: 'Photo Frame',
    desc: 'A slideshow of your own photos.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.photo_fill,
    face: _photos,
    editor: (ctx) => const _PhotoEditor(),
  ),
  WDef(
    no: 34,
    id: 'quote',
    name: 'Daily Quote',
    desc: 'A new quote every day.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.quote_bubble_fill,
    preferred: WSize.medium,
    face: _quote,
  ),
  WDef(
    no: 35,
    id: 'mood',
    name: 'Mood Journal',
    desc: 'Log how you feel and see your week.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.smiley_fill,
    face: _mood,
    editor: (ctx) => const _MoodEditor(),
  ),
  WDef(
    no: 36,
    id: 'water',
    name: 'Hydration',
    desc: 'Count glasses of water toward a daily goal.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.drop_fill,
    face: _water,
    editor: (ctx) => const _WaterEditor(),
  ),
  WDef(
    no: 37,
    id: 'sleep',
    name: 'Sleep Rhythm',
    desc: 'Sleep duration and schedule over the week.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.bed_double_fill,
    face: _sleep,
    editor: (ctx) => const _SleepEditor(),
  ),
  WDef(
    no: 38,
    id: 'fitness',
    name: 'Fitness Rings',
    desc: 'Steps, move and active minutes as rings.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.circle_grid_hex_fill,
    face: _fitness,
    editor: (ctx) => const _FitnessEditor(),
  ),
  WDef(
    no: 39,
    id: 'reading',
    name: 'Reading Tracker',
    desc: 'Books, pages read and progress.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.book_fill,
    face: _reading,
    editor: (ctx) => const _ReadingEditor(),
  ),
  WDef(
    no: 40,
    id: 'prayer',
    name: 'Prayer Times',
    desc: 'Daily prayer times with a countdown to the next.',
    cat: WCat.lifestyle,
    icon: CupertinoIcons.moon_stars_fill,
    preferred: WSize.medium,
    face: _prayer,
    editor: (ctx) => const _PrayerEditor(),
  ),
];

// ───────────────────────── 31 Now Playing ─────────────────────────

Widget _eq(WCtx c, bool on, double h) {
  final t = DateTime.now().second;
  return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
    for (var i = 0; i < 4; i++)
      Container(
        width: 3.5,
        height: on ? h * (0.35 + 0.65 * ((math.sin(t * 1.7 + i * 1.3) + 1) / 2)) : h * 0.25,
        margin: const EdgeInsets.only(right: 2.5),
        decoration: BoxDecoration(color: c.fg, borderRadius: BorderRadius.circular(2), boxShadow: on ? c.boxGlow(c.fg, 0.3) : null),
      ),
  ]);
}

Widget _nowPlaying(WCtx c) {
  final s = soundscape;
  final m = media.value;
  final internal = !m.hasTrack && s.playing != null;
  if (!m.hasTrack && !internal) {
    return WEmpty(c, CupertinoIcons.music_note_2,
      media.supported && !m.allowed ? 'Enable media access to see what’s playing.' : 'Nothing playing. Start music in a media app.', title: 'Now Playing');
  }
  final on = internal || m.playing;
  final title = internal ? s.playing! : m.title;
  final artist = internal ? 'Soundscape · So Widget' : m.artist;
  final art = Container(
    decoration: ShapeDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.accent == c.fg ? const Color(0xFF3A3A3C) : c.accent, c.bg],
      ),
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(c.s.radius * 0.45)),
      shadows: c.boxGlow(c.accent, 0.4),
    ),
    child: !internal && media.artwork != null
      ? ClipRRect(borderRadius: BorderRadius.circular(c.s.radius * 0.45), child: RawImage(image: media.artwork, fit: BoxFit.cover))
      : Center(child: Icon(internal ? CupertinoIcons.waveform : CupertinoIcons.music_note_2, color: c.fg, size: c.sm ? 26 : 34)),
  );
  final listening = internal ? 'Soundscape' : (on ? 'Now playing' : 'Paused');
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [SizedBox(width: 54, height: 54, child: art), const Spacer(), _eq(c, on, 22)]),
        const Spacer(),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(17)),
        Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(13, dim: true)),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: c.md
        ? Row(children: [
            AspectRatio(aspectRatio: 1, child: art),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [Expanded(child: Text(listening, style: c.t(12, dim: true))), _eq(c, on, 16)]),
                const SizedBox(height: 6),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(22, h: 1.1)),
                Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(14, dim: true)),
                const SizedBox(height: 12),
                if (!internal && m.duration > 0) GlowBar(c, m.progress, height: 4),
              ]),
            ),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: art))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(24))),
              _eq(c, on, 20),
            ]),
            Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(15, dim: true)),
            const SizedBox(height: 12),
            if (!internal && m.duration > 0) GlowBar(c, m.progress, height: 5),
          ]),
  );
}

// ───────────────────────── 32 Soundscape ─────────────────────────

IconData soundIcon(String n) => switch (n) {
      'Rain' => CupertinoIcons.cloud_rain_fill,
      'Fireplace' => CupertinoIcons.flame_fill,
      'Ocean' => CupertinoIcons.drop_fill,
      'Wind' => CupertinoIcons.wind,
      _ => CupertinoIcons.waveform,
    };

Widget _sound(WCtx c) {
  final s = soundscape;
  final on = s.playing != null;
  final name = s.playing ?? app.store.str('sound.last', 'Rain');
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, null, on ? 'Playing' : 'Soundscape'),
        const Spacer(),
        Icon(soundIcon(name), size: 38, color: c.fg, shadows: on ? c.glowFor(c.fg, 1.2) : null),
        const SizedBox(height: 8),
        Text(name, style: c.t(20)),
        const SizedBox(height: 8),
        GlowBar(c, s.volume, height: 5),
      ]),
    );
  }
  final max = c.md ? 3 : 6;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.waveform, on ? 'Playing · $name' : 'Soundscape', trailing: '${(s.volume * 100).round()}%'),
      const SizedBox(height: 10),
      Expanded(
        child: GridView.count(
          crossAxisCount: c.md ? 3 : 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: c.md ? 1.05 : 1.45,
          children: [
            for (final n in Soundscape.sounds.take(max))
              Tile(
                c,
                color: n == s.playing ? c.fg : c.faint,
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(soundIcon(n), size: 20, color: n == s.playing ? c.bg : c.fg),
                  const Spacer(),
                  fit(Text(n, style: c.t(13, c: n == s.playing ? c.bg : c.fg, glow: false))),
                ]),
              ),
          ],
        ),
      ),
    ]),
  );
}

class _SoundEditor extends StatelessWidget {
  const _SoundEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: soundscape,
        builder: (context, _) {
          final s = soundscape;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final n in Soundscape.sounds)
                    GestureDetector(
                      onTap: () {
                        tapFeedback();
                        app.store.set('sound.last', n);
                        s.toggle(n);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: ShapeDecoration(
                          color: s.playing == n ? Colors.white : K.card,
                          shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          s.loading && s.playing == n
                              ? const CupertinoActivityIndicator(color: Colors.black)
                              : Icon(soundIcon(n), color: s.playing == n ? Colors.black : Colors.white, size: 28),
                          const SizedBox(height: 8),
                          Text(n, style: TextStyle(fontSize: 13, color: s.playing == n ? Colors.black : K.label2, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            Section(
              footer: 'Sounds are synthesized on your device and loop seamlessly. Tap again to stop.',
              children: [SliderRow('Volume', s.volume, s.setVolume, label: '${(s.volume * 100).round()}%')],
            ),
          ]);
        },
      );
}

// ───────────────────────── 33 Photo Frame ─────────────────────────

Widget _photos(WCtx c) {
  final ps = app.store.strs('photos');
  if (ps.isEmpty) return WEmpty(c, CupertinoIcons.photo, 'Pick photos for your frame.', title: 'Photo Frame');
  final every = app.store.n('photos.every', 30).toInt().clamp(1, 1440);
  final idx = (DateTime.now().millisecondsSinceEpoch ~/ (every * 60000)) % ps.length;
  final path = ps[idx];
  final img = app.pix.get('file:$path', () => File(path).readAsBytes());
  final now = DateTime.now();
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.sm ? 14 : 18),
    background: img == null
        ? null
        : Stack(fit: StackFit.expand, children: [
            RawImage(image: img, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  stops: const [0.5, 1],
                ),
              ),
            ),
          ]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Spacer(),
      if (!c.sm) Text(kDays[now.weekday - 1], style: c.script(c.lg ? 44 : 32, c: Colors.white)),
      Text('${now.day} ${kMonths[now.month - 1].toUpperCase()}', style: c.t(c.sm ? 12 : 15, w: FontWeight.w800, c: Colors.white, ls: 0.6)),
    ]),
  );
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor();

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 88);
    if (files.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    final out = <String>[];
    for (final f in files) {
      final dest = '${dir.path}/photo_${DateTime.now().microsecondsSinceEpoch}_${out.length}.jpg';
      await File(f.path).copy(dest);
      out.add(dest);
    }
    app.store.set('photos', [...app.store.strs('photos'), ...out]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.store, app.pix]),
        builder: (context, _) {
          final ps = app.store.strs('photos');
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: PillButton('Add photos', icon: CupertinoIcons.photo_on_rectangle, onTap: _pick),
            ),
            if (ps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < ps.length; i++)
                      GestureDetector(
                        onLongPress: () async {
                          if (!await confirm(context, 'Remove photo?', 'It will be removed from the frame.', action: 'Remove')) return;
                          app.store.set('photos', [...ps]..removeAt(i));
                        },
                        child: ClipRSuperellipse(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(ps[i]), fit: BoxFit.cover, cacheWidth: 240),
                        ),
                      ),
                  ],
                ),
              ),
            Section(footer: 'Long-press a photo to remove it.', children: [
              StepperRow('Change every', app.store.n('photos.every', 30), (v) => app.store.set('photos.every', v),
                  min: 5, max: 1440, step: 5, format: (v) => v >= 60 ? '${(v / 60).toStringAsFixed(v % 60 == 0 ? 0 : 1)} h' : '${v.toInt()} min'),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 34 Daily Quote ─────────────────────────

const _quotes = [
  ('The impediment to action advances action. What stands in the way becomes the way.', 'Marcus Aurelius'),
  ('Well begun is half done.', 'Aristotle'),
  ('He who has a why to live can bear almost any how.', 'Friedrich Nietzsche'),
  ('Simplicity is the ultimate sophistication.', 'Leonardo da Vinci'),
  ('We suffer more often in imagination than in reality.', 'Seneca'),
  ('The journey of a thousand miles begins with one step.', 'Lao Tzu'),
  ('Knowing yourself is the beginning of all wisdom.', 'Aristotle'),
  ('Patience is bitter, but its fruit is sweet.', 'Jean-Jacques Rousseau'),
  ('Whatever you are, be a good one.', 'Abraham Lincoln'),
  ('Nothing in life is to be feared, it is only to be understood.', 'Marie Curie'),
  ('It does not matter how slowly you go as long as you do not stop.', 'Confucius'),
  ('Luck is what happens when preparation meets opportunity.', 'Seneca'),
  ('Quality is not an act, it is a habit.', 'Aristotle'),
  ('Be curious, not judgmental.', 'Walt Whitman'),
  ('The best way out is always through.', 'Robert Frost'),
  ('Do not wait to strike till the iron is hot; make it hot by striking.', 'W. B. Yeats'),
  ('Act as if what you do makes a difference. It does.', 'William James'),
  ('Little by little, one travels far.', 'J. R. R. Tolkien'),
  ('What we think, we become.', 'Buddha'),
  ('The secret of getting ahead is getting started.', 'Mark Twain'),
  ('Seek knowledge from the cradle to the grave.', 'Proverb'),
  ('He who knows others is wise; he who knows himself is enlightened.', 'Lao Tzu'),
  ('Wherever you go, go with all your heart.', 'Confucius'),
  ('Your task is not to seek for love, but to find the barriers you have built against it.', 'Rumi'),
  ('Yesterday I was clever, so I wanted to change the world. Today I am wise, so I am changing myself.', 'Rumi'),
  ('Science is the greatest of treasures.', 'Ulugh Beg'),
  ('Perfection is achieved when there is nothing left to take away.', 'Antoine de Saint-Exupéry'),
  ('Order and simplification are the first steps toward mastery.', 'Thomas Mann'),
  ('Energy and persistence conquer all things.', 'Benjamin Franklin'),
  ('First say to yourself what you would be; then do what you have to do.', 'Epictetus'),
];

int dayIndex(int n, [int salt = 0]) {
  final d = DateTime.now();
  final days = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
  return (days * 7 + salt) % n;
}

Widget _quote(WCtx c) {
  final q = _quotes[dayIndex(_quotes.length)];
  final fs = switch (c.size) { WSize.small => 17.0, WSize.medium => 24.0, WSize.large => 32.0 };
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 28 : (c.sm ? 16 : 20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('“', style: c.script(c.lg ? 80 : 44, c: c.dim).copyWith(height: 0.9)),
      Expanded(
        child: fit(
          SizedBox(
            width: c.dims.width - (c.lg ? 56 : (c.sm ? 32 : 40)),
            child: Text(q.$1, style: c.t(fs, w: FontWeight.w600, h: 1.22)),
          ),
          a: Alignment.topLeft,
        ),
      ),
      const SizedBox(height: 6),
      Text('— ${q.$2}', style: c.t(c.sm ? 12 : 14, dim: true)),
    ]),
  );
}

// ───────────────────────── 35 Mood ─────────────────────────

const _moods = ['Rough', 'Low', 'Okay', 'Good', 'Great'];
const _moodIcons = [
  CupertinoIcons.cloud_bolt_fill,
  CupertinoIcons.cloud_fill,
  CupertinoIcons.cloud_sun_fill,
  CupertinoIcons.sun_min_fill,
  CupertinoIcons.sun_max_fill,
];

Widget _mood(WCtx c) {
  final m = app.store.map('mood');
  final now = DateTime.now();
  final today = (m[dkey(now)] as num?)?.toInt();
  final week = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
  Widget bars(double h) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final d in week)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                height: m[dkey(d)] == null ? 4 : h * ((m[dkey(d)] as num).toInt() + 1) / 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: m[dkey(d)] == null ? c.faint : c.fg.withValues(alpha: dkey(d) == dkey(now) ? 1 : 0.55),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: dkey(d) == dkey(now) && m[dkey(d)] != null ? c.boxGlow(c.fg, 0.5) : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(kDays[d.weekday - 1][0], style: c.t(10, dim: true)),
            ]),
          ),
      ]);
  final word = today == null ? 'How are you?' : _moods[today];
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(today == null ? CupertinoIcons.smiley : _moodIcons[today], size: 22, color: c.fg, shadows: c.glowFor(c.fg)),
          const Spacer(),
          Text('Today', style: c.t(12, dim: true)),
        ]),
        const SizedBox(height: 6),
        fit(Text(word, style: today == null ? c.t(18) : c.script(34))),
        const Spacer(),
        SizedBox(height: 48, child: bars(28)),
      ]),
    );
  }
  final logged = week.where((d) => m[dkey(d)] != null).map((d) => (m[dkey(d)] as num).toInt()).toList();
  final avg = logged.isEmpty ? null : logged.reduce((a, b) => a + b) / logged.length;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: c.md
        ? Row(children: [
            SizedBox(
              width: 120,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mood', style: c.t(14, dim: true)),
                const Spacer(),
                Icon(today == null ? CupertinoIcons.smiley : _moodIcons[today], size: 26, color: c.fg, shadows: c.glowFor(c.fg)),
                fit(Text(word, style: today == null ? c.t(18) : c.script(36))),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: bars(84)),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WHeader(c, CupertinoIcons.smiley, 'Mood Journal', trailing: avg == null ? null : 'avg ${_moods[avg.round()]}'),
            const SizedBox(height: 12),
            Icon(today == null ? CupertinoIcons.smiley : _moodIcons[today], size: 36, color: c.fg, shadows: c.glowFor(c.fg)),
            Text(word, style: today == null ? c.t(26) : c.script(54)),
            const SizedBox(height: 12),
            Expanded(child: bars(150)),
          ]),
  );
}

class _MoodEditor extends StatelessWidget {
  const _MoodEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final m = app.store.map('mood');
          final k = dkey(DateTime.now());
          final cur = (m[k] as num?)?.toInt();
          return Section(
            title: 'How do you feel today?',
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 5; i++)
                      GestureDetector(
                        onTap: () {
                          tapFeedback();
                          m[k] = i;
                          app.store.set('mood', m);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 58,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: ShapeDecoration(
                            color: cur == i ? Colors.white : K.card2,
                            shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Column(children: [
                            Icon(_moodIcons[i], color: cur == i ? Colors.black : Colors.white),
                            const SizedBox(height: 4),
                            Text(_moods[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: cur == i ? Colors.black : K.label2)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

// ───────────────────────── 36 Hydration ─────────────────────────

Widget _water(WCtx c) {
  final w = app.store.map('water');
  final n = (w[dkey(DateTime.now())] as num? ?? 0).toInt();
  final goal = app.store.n('water.goal', 8).toInt();
  final ml = app.store.n('water.ml', 250).toInt();
  final v = n / math.max(1, goal);
  final water = c.accent == c.fg ? const Color(0xFF64D2FF) : c.accent;
  final liters = (n * ml / 1000).toStringAsFixed(n * ml % 1000 == 0 ? 0 : 2);
  Widget glass(double size) => SizedBox(
        width: size * 0.7,
        height: size,
        child: CustomPaint(painter: _GlassPainter(v.clamp(0, 1), c.fg, water, c.s.glow ? c.s.glowStrength : 0)),
      );
  if (c.sm) {
    return WShell(
      c: c,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WHeader(c, CupertinoIcons.drop_fill, 'Water'),
            const Spacer(),
            Text('$n', style: c.t(46, w: FontWeight.w600, h: 1)),
            Text('of $goal glasses', style: c.t(12, dim: true)),
            Text('$liters L', style: c.t(13, c: water)),
          ]),
        ),
        glass(100),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : 18),
    child: c.md
        ? Row(children: [
            glass(130),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Hydration', style: c.t(14, dim: true)),
                fit(Text('$liters L', style: c.t(46, w: FontWeight.w600))),
                Text('$n of $goal glasses · ${(v * 100).round()}%', style: c.t(14, dim: true)),
                const SizedBox(height: 10),
                Row(children: [
                  for (var i = 0; i < goal && i < 12; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i < n ? water : c.faint),
                    ),
                ]),
              ]),
            ),
          ])
        : Column(children: [
            WHeader(c, CupertinoIcons.drop_fill, 'Hydration', trailing: '${(v * 100).round()}%'),
            Expanded(child: Center(child: glass(200))),
            Text('$liters L', style: c.t(40, w: FontWeight.w600)),
            Text('$n of $goal glasses', style: c.t(15, dim: true)),
          ]),
  );
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.v, this.fg, this.water, this.glow);
  final double v, glow;
  final Color fg, water;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * 0.05, 0)
      ..lineTo(s.width * 0.95, 0)
      ..lineTo(s.width * 0.82, s.height)
      ..lineTo(s.width * 0.18, s.height)
      ..close();
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(path, Paint()..color = fg.withValues(alpha: 0.07));
    final top = s.height * (1 - v);
    final wave = Path()..moveTo(0, top);
    for (var x = 0.0; x <= s.width; x += 2) {
      wave.lineTo(x, top + math.sin(x / s.width * math.pi * 2) * 3);
    }
    wave
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    if (glow > 0) {
      canvas.drawPath(wave, Paint()
        ..color = water.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glow + 2));
    }
    canvas.drawPath(wave, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [water, water.withValues(alpha: 0.7)],
      ).createShader(Offset.zero & s));
    canvas.restore();
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = fg.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _GlassPainter o) => o.v != v || o.water != water;
}

class _WaterEditor extends StatelessWidget {
  const _WaterEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final w = app.store.map('water');
          final k = dkey(DateTime.now());
          final n = (w[k] as num? ?? 0).toInt();
          void set(int v) {
            w[k] = math.max(0, v);
            app.store.set('water', w);
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: Row(children: [
                Expanded(child: PillButton('Drink a glass', icon: CupertinoIcons.drop_fill, onTap: () => set(n + 1))),
                const SizedBox(width: 10),
                PillButton('', icon: CupertinoIcons.minus, filled: false, onTap: n > 0 ? () => set(n - 1) : null),
              ]),
            ),
            Section(title: 'Goal', children: [
              StepperRow('Daily goal', app.store.n('water.goal', 8), (v) => app.store.set('water.goal', v), min: 1, max: 20, format: (v) => '$v glasses'),
              StepperRow('Glass size', app.store.n('water.ml', 250), (v) => app.store.set('water.ml', v), min: 100, max: 1000, step: 50, format: (v) => '$v ml'),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 37 Sleep ─────────────────────────

Duration _sleepDur(Map<String, dynamic> e) {
  int mins(String s) {
    final p = s.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  var d = mins('${e['wake']}') - mins('${e['bed']}');
  if (d <= 0) d += 1440;
  return Duration(minutes: d);
}

Widget _sleep(WCtx c) {
  final log = app.store.list('sleep')..sort((a, b) => '${a['d']}'.compareTo('${b['d']}'));
  if (log.isEmpty) return WEmpty(c, CupertinoIcons.bed_double, 'Log last night’s sleep.', title: 'Sleep');
  final last = log.last;
  final d = _sleepDur(last);
  final week = log.length > 7 ? log.sublist(log.length - 7) : log;
  final avg = Duration(minutes: week.fold<int>(0, (a, e) => a + _sleepDur(e).inMinutes) ~/ week.length);
  final moon = c.accent == c.fg ? const Color(0xFFBF9BFF) : c.accent;
  Widget bars(double h) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final e in week)
          Expanded(
            child: Container(
              height: h * (_sleepDur(e).inMinutes / 600).clamp(0.08, 1.0),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: e == last ? moon : moon.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(5),
                boxShadow: e == last ? c.boxGlow(moon, 0.5) : null,
              ),
            ),
          ),
      ]);
  final big = '${d.inHours}h ${d.inMinutes % 60}m';
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.bed_double_fill, 'Last night'),
        fit(Text(big, style: c.t(34, w: FontWeight.w600))),
        Text('${last['bed']} → ${last['wake']}', style: c.t(12, dim: true)),
        const Spacer(),
        SizedBox(height: 40, child: bars(40)),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.bed_double_fill, 'Sleep Rhythm', trailing: 'avg ${avg.inHours}h ${avg.inMinutes % 60}m'),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(big, style: c.t(c.lg ? 50 : 34, w: FontWeight.w600)),
        const SizedBox(width: 10),
        Text('${last['bed']} → ${last['wake']}', style: c.t(14, dim: true)),
      ]),
      const SizedBox(height: 12),
      Expanded(child: bars(c.lg ? 220 : 60)),
    ]),
  );
}

class _SleepEditor extends StatelessWidget {
  const _SleepEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final log = app.store.list('sleep')..sort((a, b) => '${b['d']}'.compareTo('${a['d']}'));
          return ListEditor(
            title: 'Sleep log',
            items: log,
            titleOf: (m) => '${m['bed']} → ${m['wake']}  ·  ${_sleepDur(m).inHours}h ${_sleepDur(m).inMinutes % 60}m',
            subtitleOf: (m) => '${m['d']}',
            addLabel: 'Log sleep',
            footer: 'Add bedtime and wake time for each night.',
            onAdd: () async {
              final now = DateTime.now();
              final bed = await pickDateTime(context,
                  mode: CupertinoDatePickerMode.time, initial: DateTime(now.year, now.month, now.day, 23, 30), use24h: true);
              if (bed == null || !context.mounted) return;
              final wake = await pickDateTime(context,
                  mode: CupertinoDatePickerMode.time, initial: DateTime(now.year, now.month, now.day, 7, 0), use24h: true);
              if (wake == null) return;
              final key = dkey(now);
              app.store.set('sleep', [
                ...log.where((e) => e['d'] != key),
                {'d': key, 'bed': '${two(bed.hour)}:${two(bed.minute)}', 'wake': '${two(wake.hour)}:${two(wake.minute)}'},
              ]);
            },
            onDelete: (i) => app.store.set('sleep', [...log]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 38 Fitness Rings ─────────────────────────

const _ringColors = [Color(0xFFFF2D55), Color(0xFFA6FF00), Color(0xFF00E0FF)];

Widget _fitness(WCtx c) {
  final day = app.store.map('fit')[dkey(DateTime.now())] as Map? ?? {};
  final g = app.store.map('fit.goals');
  num v(String k) => day[k] as num? ?? 0;
  num goal(String k) => g[k] as num? ?? 1;
  final vals = [v('steps') / goal('steps'), v('move') / goal('move'), v('active') / goal('active')].map((e) => e.toDouble()).toList();
  final rings = Rings(c, vals, colors: _ringColors, stroke: c.sm ? 13 : (c.lg ? 22 : 15), gap: 3);
  Widget stat(int i, String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: c.t(12, dim: true)),
        Text(value, style: c.t(c.lg ? 22 : 17, c: _ringColors[i])),
      ]);
  if (c.sm) return WShell(c: c, child: Center(child: rings));
  final stats = [
    stat(0, 'Steps', '${groupNum(v('steps'))}/${groupNum(goal('steps'))}'),
    stat(1, 'Move', '${v('move')}/${goal('move')} kcal'),
    stat(2, 'Active', '${v('active')}/${goal('active')} min'),
  ];
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : 18),
    child: c.md
        ? Row(children: [
            ConstrainedBox(constraints: BoxConstraints(maxWidth: c.dims.width * 0.42), child: rings),
            const SizedBox(width: 22),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: stats)),
          ])
        : Column(children: [
            Expanded(child: rings),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final s in stats) Flexible(child: fit(s))]),
          ]),
  );
}

class _FitnessEditor extends StatelessWidget {
  const _FitnessEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final all = app.store.map('fit');
          final k = dkey(DateTime.now());
          final day = Map<String, dynamic>.from(all[k] as Map? ?? {});
          final g = app.store.map('fit.goals');
          void set(String f, num v) {
            day[f] = v;
            all[k] = day;
            app.store.set('fit', all);
          }

          void setGoal(String f, num v) {
            g[f] = v;
            app.store.set('fit.goals', g);
          }

          return Column(children: [
            Section(title: 'Today', footer: 'Enter values from your watch or health app.', children: [
              StepperRow('Steps', day['steps'] as num? ?? 0, (v) => set('steps', v), step: 500),
              StepperRow('Move (kcal)', day['move'] as num? ?? 0, (v) => set('move', v), step: 25),
              StepperRow('Active (min)', day['active'] as num? ?? 0, (v) => set('active', v), step: 5),
            ]),
            Section(title: 'Goals', children: [
              StepperRow('Steps', g['steps'] as num? ?? 8000, (v) => setGoal('steps', v), min: 1000, step: 500),
              StepperRow('Move (kcal)', g['move'] as num? ?? 500, (v) => setGoal('move', v), min: 50, step: 25),
              StepperRow('Active (min)', g['active'] as num? ?? 30, (v) => setGoal('active', v), min: 5, step: 5),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 39 Reading ─────────────────────────

Widget _reading(WCtx c) {
  final books = app.store.list('books');
  if (books.isEmpty) return WEmpty(c, CupertinoIcons.book, 'Add the book you’re reading.', title: 'Reading');
  final b = books.first;
  final p = (b['p'] as num? ?? 0).toInt(), n = math.max(1, (b['n'] as num? ?? 1).toInt());
  final v = p / n;
  final cover = Container(
    decoration: ShapeDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.fg.withValues(alpha: 0.9), c.fg.withValues(alpha: 0.55)]),
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(8)),
      shadows: c.boxGlow(c.fg, 0.3),
    ),
    padding: const EdgeInsets.all(8),
    child: Align(
      alignment: Alignment.bottomLeft,
      child: Text('${b['t']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: c.t(10, c: c.bg, glow: false, w: FontWeight.w800, h: 1.1)),
    ),
  );
  if (c.sm) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.book_fill, 'Reading'),
        const Spacer(),
        Text('${b['t']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(17, h: 1.1)),
        Text('p. $p of $n', style: c.t(12, dim: true)),
        const SizedBox(height: 10),
        GlowBar(c, v, height: 6),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Row(children: [
          AspectRatio(aspectRatio: 0.68, child: cover),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(builder: (context, bc) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: bc.maxWidth,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Currently reading', style: c.t(12, dim: true)),
              const SizedBox(height: 4),
              Text('${b['t']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(c.lg ? 24 : 19, h: 1.1)),
              Text('${b['a']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(14, dim: true)),
              const SizedBox(height: 8),
              Text('${(v * 100).round()}%', style: c.t(c.lg ? 40 : 26, w: FontWeight.w600)),
                ]),
              ),
            )),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      GlowBar(c, v, height: c.lg ? 10 : 6),
      const SizedBox(height: 6),
      Row(children: [
        Text('p. $p of $n', style: c.t(12, dim: true)),
        const Spacer(),
        Text('${n - p} pages left', style: c.t(12, dim: true)),
      ]),
      if (c.lg && books.length > 1) ...[
        Divider(color: c.line, height: 20),
        Text('Up next: ${books[1]['t']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(14, dim: true)),
      ],
    ]),
  );
}

class _ReadingEditor extends StatelessWidget {
  const _ReadingEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final books = app.store.list('books');
          return Column(children: [
            if (books.isNotEmpty)
              Section(title: 'Current: ${books.first['t']}', children: [
                StepperRow('Page', books.first['p'] as num? ?? 0, (v) {
                  books.first['p'] = v;
                  app.store.set('books', books);
                }, max: books.first['n'] as num? ?? 9999, step: 5),
              ]),
            ListEditor(
              title: 'Books',
              items: books,
              titleOf: (m) => '${m['t']}',
              subtitleOf: (m) => '${m['a']} · ${m['p']}/${m['n']}',
              addLabel: 'Add book',
              footer: 'The first book is shown on the widget. Tap a book to make it current.',
              onTap: (i) {
                final b = books.removeAt(i);
                app.store.set('books', [b, ...books]);
              },
              onAdd: () async {
                final r = await promptFields(context,
                    title: 'New book', labels: ['Title', 'Author', 'Total pages'], keyboards: [null, null, TextInputType.number]);
                if (r == null || r[0].isEmpty) return;
                app.store.set('books', [{'t': r[0], 'a': r[1], 'p': 0, 'n': int.tryParse(r[2]) ?? 300}, ...books]);
              },
              onDelete: (i) => app.store.set('books', [...books]..removeAt(i)),
            ),
          ]);
        },
      );
}

// ───────────────────────── 40 Prayer Times ─────────────────────────

const _prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
const _methods = {
  3: 'Muslim World League',
  2: 'ISNA (North America)',
  4: 'Umm al-Qura, Makkah',
  5: 'Egyptian Authority',
  1: 'Karachi',
  13: 'Diyanet, Turkey',
  8: 'Gulf Region',
  14: 'Spiritual Admin. of Muslims of Russia',
};

String get _prayerKey {
  final s = app.settings;
  return 'prayer:${s.lat.toStringAsFixed(2)},${s.lon.toStringAsFixed(2)}:${app.store.n('prayer.method', 3)}:${app.store.n('prayer.school', 1)}:${dkey(DateTime.now())}';
}

Widget _prayer(WCtx c) {
  final s = app.settings;
  app.hub.ensure(_prayerKey, const Duration(hours: 6),
      () => Api.prayer(s.lat, s.lon, app.store.n('prayer.method', 3).toInt(), app.store.n('prayer.school', 1).toInt()));
  final j = app.hub.get<Map<String, dynamic>>(_prayerKey);
  if (j == null) return WEmpty(c, CupertinoIcons.moon_stars, 'Loading prayer times for ${s.city}…', title: 'Prayer Times');
  final tm = Map<String, dynamic>.from((j['data'] as Map)['timings'] as Map);
  final now = DateTime.now();
  DateTime at(String name) {
    final p = '${tm[name]}'.split(' ').first.split(':');
    return DateTime(now.year, now.month, now.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  final times = {for (final p in _prayers) p: at(p)};
  final five = _prayers.where((p) => p != 'Sunrise').toList();
  var next = five.firstWhere((p) => times[p]!.isAfter(now), orElse: () => 'Fajr');
  var nextAt = times[next]!;
  if (!nextAt.isAfter(now)) nextAt = nextAt.add(const Duration(days: 1));
  final current = five.lastWhere((p) => !times[p]!.isAfter(now), orElse: () => 'Isha');
  final h24 = app.settings.use24h;
  final until = nextAt.difference(now);
  final gold = c.warm;

  Widget row(String p, double fs) {
    final isNext = p == next;
    return Row(children: [
      Text(p, style: c.t(fs, c: isNext ? gold : (p == current ? c.fg : c.dim), glow: isNext)),
      const Spacer(),
      Text(hm(times[p]!, h24), style: c.t(fs, c: isNext ? gold : (p == current ? c.fg : c.dim), glow: isNext)),
    ]);
  }

  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.moon_stars_fill, 'Next prayer'),
          const Spacer(),
          Text(next, style: c.script(36, c: gold)),
          fit(Text(hm(nextAt, h24), style: c.t(32, w: FontWeight.w600))),
          Text('in ${dur(until, short: true)}', style: c.t(12, dim: true)),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WHeader(c, CupertinoIcons.moon_stars_fill, s.city),
              const Spacer(),
              Text(next, style: c.script(40, c: gold)),
              Text(hm(nextAt, h24), style: c.t(26, w: FontWeight.w600)),
              Text('in ${dur(until, short: true)}', style: c.t(13, dim: true)),
            ]),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 130,
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final p in five) row(p, 14)]),
          ),
        ]),
      );
    case WSize.large:
      final hijri = (j['data'] as Map)['date']?['hijri'];
      return WShell(
        c: c,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.moon_stars_fill, s.city,
              trailing: hijri == null ? null : '${hijri['day']} ${hijri['month']?['en']} ${hijri['year']}'),
          const SizedBox(height: 10),
          Text(next, style: c.script(54, c: gold)),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(hm(nextAt, h24), style: c.t(34, w: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('in ${dur(until, short: true)}', style: c.t(15, dim: true)),
          ]),
          Divider(color: c.line, height: 26),
          for (final p in _prayers) Expanded(child: Center(child: row(p, 17))),
        ]),
      );
  }
}

class _PrayerEditor extends StatelessWidget {
  const _PrayerEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) => Column(children: [
          const LocationSection(showUnits: false),
          Section(title: 'Calculation', children: [
            RowItem(
              title: 'Method',
              value: _methods[app.store.n('prayer.method', 3).toInt()] ?? '',
              onTap: () => showSheet(
                context,
                ListView(shrinkWrap: true, children: [
                  Section(children: [
                    for (final e in _methods.entries)
                      RowItem(
                        title: e.value,
                        trailing: app.store.n('prayer.method', 3) == e.key ? const Icon(CupertinoIcons.checkmark, color: K.blue, size: 18) : null,
                        onTap: () {
                          app.store.set('prayer.method', e.key);
                          Navigator.pop(context);
                        },
                      ),
                  ]),
                ]),
                title: 'Method',
              ),
            ),
            RowItem(
              title: 'Asr',
              trailing: SizedBox(
                width: 170,
                child: Seg<int>(
                  value: app.store.n('prayer.school', 1).toInt(),
                  items: const {0: 'Standard', 1: 'Hanafi'},
                  onChanged: (v) => app.store.set('prayer.school', v),
                ),
              ),
            ),
          ]),
          RefreshRow(_prayerKey),
        ]),
      );
}


// ───────────────────────── One-row glances ─────────────────────────

final lifestyleGlances = <String, Glance Function(WCtx)>{
  'nowplaying': (c) => mediaGlance(c),
  'soundscape': (c) {
    final s = soundscape;
    return Glance(s.playing ?? app.store.str('sound.last', 'Rain'),
        label: s.playing == null ? 'Soundscape · tap to play' : 'Playing · ${(s.volume * 100).round()}%',
        icon: soundIcon(s.playing ?? app.store.str('sound.last', 'Rain')));
  },
  'photos': (c) {
    final n = app.store.strs('photos').length;
    return Glance('Photo Frame', label: n == 0 ? 'Pick photos in the app' : '$n photos', icon: CupertinoIcons.photo_fill);
  },
  'quote': (c) {
    final q = _quotes[dayIndex(_quotes.length)];
    return Glance('“${q.$1}”', label: '— ${q.$2}', icon: CupertinoIcons.quote_bubble_fill);
  },
  'mood': (c) {
    final today = (app.store.map('mood')[dkey(DateTime.now())] as num?)?.toInt();
    return Glance(today == null ? 'How are you?' : _moods[today], label: 'Mood today', icon: today == null ? CupertinoIcons.smiley : _moodIcons[today]);
  },
  'water': (c) {
    final n = (app.store.map('water')[dkey(DateTime.now())] as num? ?? 0).toInt();
    final goal = app.store.n('water.goal', 8).toInt();
    final ml = app.store.n('water.ml', 250).toInt();
    return Glance('$n / $goal glasses', label: '${(n * ml / 1000).toStringAsFixed(2)} L today',
        icon: CupertinoIcons.drop_fill, color: c.accent == c.fg ? const Color(0xFF64D2FF) : c.accent, progress: n / math.max(1, goal));
  },
  'sleep': (c) {
    final log = app.store.list('sleep')..sort((a, b) => '${a['d']}'.compareTo('${b['d']}'));
    if (log.isEmpty) return const Glance('—', label: 'Log last night', icon: CupertinoIcons.bed_double_fill);
    final d = _sleepDur(log.last);
    return Glance('${d.inHours}h ${d.inMinutes % 60}m', label: '${log.last['bed']} → ${log.last['wake']}', icon: CupertinoIcons.bed_double_fill);
  },
  'fitness': (c) {
    final day = app.store.map('fit')[dkey(DateTime.now())] as Map? ?? {};
    final g = app.store.map('fit.goals');
    final steps = (day['steps'] as num? ?? 0), goal = (g['steps'] as num? ?? 8000);
    return Glance('${groupNum(steps)} steps', label: 'Move ${day['move'] ?? 0} kcal · Active ${day['active'] ?? 0} min',
        icon: CupertinoIcons.circle_grid_hex_fill, color: _ringColors.first, progress: steps / math.max(1, goal));
  },
  'reading': (c) {
    final books = app.store.list('books');
    if (books.isEmpty) return const Glance('—', label: 'Add a book', icon: CupertinoIcons.book_fill);
    final b = books.first;
    final p = (b['p'] as num? ?? 0), n = math.max(1, (b['n'] as num? ?? 1));
    return Glance('${b['t']}', label: 'p. $p of $n · ${(p / n * 100).round()}%', icon: CupertinoIcons.book_fill, progress: p / n);
  },
  'prayer': (c) {
    final j = app.hub.get<Map<String, dynamic>>(_prayerKey);
    if (j == null) return const Glance('—', label: 'Loading prayer times', icon: CupertinoIcons.moon_stars_fill);
    final tm = Map<String, dynamic>.from((j['data'] as Map)['timings'] as Map);
    final now = DateTime.now();
    DateTime at(String name) {
      final p = '${tm[name]}'.split(' ').first.split(':');
      return DateTime(now.year, now.month, now.day, int.tryParse(p[0]) ?? 0, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    }
    final five = _prayers.where((p) => p != 'Sunrise').toList();
    final next = five.firstWhere((p) => at(p).isAfter(now), orElse: () => 'Fajr');
    var t = at(next);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return Glance('$next ${hm(t, app.settings.use24h)}', label: 'in ${dur(t.difference(now), short: true)} · ${app.settings.city}',
        icon: CupertinoIcons.moon_stars_fill, color: c.warm);
  },
};