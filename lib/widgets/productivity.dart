import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/registry.dart';
import '../core/state.dart';
import '../core/style.dart';
import '../ui/forms.dart';
import '../ui/kit.dart';
import 'common.dart';
import 'essential.dart' show BatteryPill;

void seedProductivity(Store s) {
  s.seed('focus', {'len': 25, 'brk': 5, 'mode': 'focus', 'left': 25 * 60, 'done': 0, 'day': dkey(DateTime.now())});
  s.seed('tasks', [
    {'t': 'Design new home screen', 'done': false},
    {'t': 'Reply to emails', 'done': true},
    {'t': 'Evening walk', 'done': false},
  ]);
  s.seed('habits', [
    {'n': 'Read', 'days': <String>[]},
    {'n': 'Workout', 'days': <String>[]},
    {'n': 'No sugar', 'days': <String>[]},
  ]);
  s.seed('notes.text', 'Tap to write a quick note.\nIt saves automatically.');
  s.seed('schedule', [
    {'time': '09:00', 't': 'Deep work'},
    {'time': '13:00', 't': 'Lunch'},
    {'time': '18:30', 't': 'Gym'},
  ]);
  s.seed('goals', [
    {'n': 'Savings', 'v': 640, 'max': 1000},
    {'n': 'Books', 'v': 7, 'max': 24},
  ]);
  s.seed('tracker', [
    {'n': 'So Widget', 'sec': 0},
    {'n': 'Learning', 'sec': 0},
  ]);
  s.seed('links', [
    {'l': 'qaxxorov.uz', 'u': 'https://qaxxorov.uz'},
    {'l': 'GitHub', 'u': 'https://github.com'},
    {'l': 'YouTube', 'u': 'https://youtube.com'},
    {'l': 'Maps', 'u': 'https://maps.google.com'},
  ]);
  app.clock.onSecond(Focus.tick);
}

final productivityWidgets = <WDef>[
  WDef(
    no: 11,
    id: 'focus',
    name: 'Focus',
    desc: 'Pomodoro timer with focus and break sessions.',
    cat: WCat.productivity,
    icon: CupertinoIcons.timer,
    face: _focus,
    editor: (ctx) => const _FocusEditor(),
  ),
  WDef(
    no: 12,
    id: 'tasks',
    name: 'Tasks',
    desc: 'A calm to-do list with what’s done and what’s next.',
    cat: WCat.productivity,
    icon: CupertinoIcons.checkmark_circle_fill,
    preferred: WSize.medium,
    face: _tasks,
    editor: (ctx) => const _TasksEditor(),
  ),
  WDef(
    no: 13,
    id: 'habit',
    name: 'Habit',
    desc: 'Daily habits with streaks and a weekly view.',
    cat: WCat.productivity,
    icon: CupertinoIcons.flame_fill,
    preferred: WSize.medium,
    face: _habit,
    editor: (ctx) => const _HabitEditor(),
  ),
  WDef(
    no: 14,
    id: 'notes',
    name: 'Notes',
    desc: 'A quick note that autosaves as you type.',
    cat: WCat.productivity,
    icon: CupertinoIcons.pencil_outline,
    face: _notes,
    editor: (ctx) => const _NotesEditor(),
  ),
  WDef(
    no: 15,
    id: 'schedule',
    name: 'Schedule',
    desc: 'Your daily plan and what comes next.',
    cat: WCat.productivity,
    icon: CupertinoIcons.list_bullet,
    face: _schedule,
    editor: (ctx) => const _ScheduleEditor(),
  ),
  WDef(
    no: 16,
    id: 'progress',
    name: 'Progress',
    desc: 'Goal completion percentages, plus year progress.',
    cat: WCat.productivity,
    icon: CupertinoIcons.chart_bar_fill,
    face: _progress,
    editor: (ctx) => const _ProgressEditor(),
  ),
  WDef(
    no: 17,
    id: 'tracker',
    name: 'Time Tracker',
    desc: 'Track time spent on work and projects.',
    cat: WCat.productivity,
    icon: CupertinoIcons.stopwatch_fill,
    face: _tracker,
    editor: (ctx) => const _TrackerEditor(),
  ),
  WDef(
    no: 18,
    id: 'clipboard',
    name: 'Clipboard',
    desc: 'Your recently copied text, one tap to copy again.',
    cat: WCat.productivity,
    icon: CupertinoIcons.doc_on_clipboard_fill,
    face: _clipboard,
    editor: (ctx) => const _ClipEditor(),
  ),
  WDef(
    no: 19,
    id: 'links',
    name: 'Quick Links',
    desc: 'Favorite sites and apps, one tap away.',
    cat: WCat.productivity,
    icon: CupertinoIcons.link,
    face: _links,
    editor: (ctx) => const _LinksEditor(),
  ),
  WDef(
    no: 20,
    id: 'brief',
    name: 'Daily Brief',
    desc: 'Weather, tasks and your next event in one sentence.',
    cat: WCat.productivity,
    icon: CupertinoIcons.sun_haze_fill,
    preferred: WSize.large,
    face: _brief,
  ),
];

// ───────────────────────── 11 Focus ─────────────────────────

class Focus {
  static Map<String, dynamic> get m => app.store.map('focus');

  static int get remaining {
    final f = m;
    final end = f['end'] as num?;
    if (end != null) return ((end - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 99999);
    return (f['left'] as num? ?? 0).toInt();
  }

  static bool get running => m['end'] != null;
  static bool get isBreak => m['mode'] == 'break';
  static int get total => ((isBreak ? m['brk'] : m['len']) as num? ?? 25).toInt() * 60;

  static int get doneToday => m['day'] == dkey(DateTime.now()) ? (m['done'] as num? ?? 0).toInt() : 0;

  static void _save(Map<String, dynamic> f) => app.store.set('focus', f);

  static void start() {
    final f = m;
    f['end'] = DateTime.now().millisecondsSinceEpoch + remaining * 1000;
    _save(f);
  }

  static void pause() {
    final f = m;
    f['left'] = remaining;
    f.remove('end');
    _save(f);
  }

  static void reset() {
    final f = m;
    f.remove('end');
    f['left'] = total;
    _save(f);
  }

  static void skip() => _advance(countDone: false);

  static void _advance({bool countDone = true}) {
    final f = m;
    final today = dkey(DateTime.now());
    if (f['day'] != today) {
      f['day'] = today;
      f['done'] = 0;
    }
    if (f['mode'] == 'focus') {
      if (countDone) f['done'] = (f['done'] as num? ?? 0) + 1;
      f['mode'] = 'break';
      f['left'] = (f['brk'] as num? ?? 5).toInt() * 60;
    } else {
      f['mode'] = 'focus';
      f['left'] = (f['len'] as num? ?? 25).toInt() * 60;
    }
    f.remove('end');
    _save(f);
    HapticFeedback.heavyImpact();
  }

  static void tick() {
    if (running && remaining <= 0) _advance();
  }

  static void setLen(String k, int mins) {
    final f = m;
    f[k] = mins;
    final current = (f['mode'] == 'break') == (k == 'brk');
    if (f['end'] == null && current) f['left'] = mins * 60;
    _save(f);
  }
}

String _mmss(int s) => '${two(s ~/ 60)}:${two(s % 60)}';

Widget _focus(WCtx c) {
  Widget body() {
    final left = Focus.remaining;
    final total = math.max(1, Focus.total);
    final prog = 1 - left / total;
    final mode = Focus.isBreak ? 'Break' : 'Focus';
    final status = Focus.running ? mode : '$mode · paused';
    final dots = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 4; i++)
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < Focus.doneToday % 5 || Focus.doneToday >= 4 && i < 4 ? c.fg : c.line,
          ),
        ),
    ]);
    switch (c.size) {
      case WSize.small:
        return WShell(
          c: c,
          child: Rings(c, [prog], stroke: 8, colors: [Focus.isBreak ? c.pos : c.fg], child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_mmss(left), style: c.t(28, w: FontWeight.w600)),
            Text(status, style: c.t(11, dim: true)),
          ])),
        );
      case WSize.medium:
        return WShell(
          c: c,
          child: Row(children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.dims.width * 0.4),
              child: Rings(c, [prog], stroke: 9, colors: [Focus.isBreak ? c.pos : c.fg],
                  child: Icon(Focus.isBreak ? CupertinoIcons.leaf_arrow_circlepath : CupertinoIcons.scope, size: 28, color: c.fg)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(status, style: c.t(14, dim: true)),
                fit(Text(_mmss(left), style: c.t(50, w: FontWeight.w600))),
                const SizedBox(height: 6),
                Row(children: [dots, Flexible(child: Text('${Focus.doneToday} today', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(12, dim: true)))]),
              ]),
            ),
          ]),
        );
      case WSize.large:
        return WShell(
          c: c,
          padding: const EdgeInsets.all(26),
          child: Column(children: [
            WHeader(c, CupertinoIcons.timer, status, trailing: '${Focus.doneToday} sessions'),
            const SizedBox(height: 16),
            Expanded(
              child: Rings(c, [prog], stroke: 14, colors: [Focus.isBreak ? c.pos : c.fg], child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_mmss(left), style: c.t(56, w: FontWeight.w600)),
                Text(Focus.isBreak ? 'Breathe' : 'Stay with it', style: c.script(26)),
              ])),
            ),
          ]),
        );
    }
  }

  if (!c.live) return body();
  return ListenableBuilder(listenable: app.clock.second, builder: (context, _) => body());
}

class _FocusEditor extends StatelessWidget {
  const _FocusEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.store, app.clock.second]),
        builder: (context, _) {
          final f = Focus.m;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: Row(children: [
                Expanded(
                  child: PillButton(Focus.running ? 'Pause' : 'Start',
                      icon: Focus.running ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      onTap: Focus.running ? Focus.pause : Focus.start),
                ),
                const SizedBox(width: 10),
                PillButton('', icon: CupertinoIcons.arrow_counterclockwise, filled: false, onTap: Focus.reset),
                const SizedBox(width: 10),
                PillButton('', icon: CupertinoIcons.forward_end_fill, filled: false, onTap: Focus.skip),
              ]),
            ),
            Section(title: 'Session', children: [
              StepperRow('Focus length', (f['len'] as num? ?? 25), (v) => Focus.setLen('len', v.toInt()),
                  min: 5, max: 120, step: 5, format: (v) => '${v.toInt()} min'),
              StepperRow('Break length', (f['brk'] as num? ?? 5), (v) => Focus.setLen('brk', v.toInt()),
                  min: 1, max: 60, step: 1, format: (v) => '${v.toInt()} min'),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 12 Tasks ─────────────────────────

Widget _check(WCtx c, bool done, double s) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c.fg : null,
        border: Border.all(color: done ? c.fg : c.dim, width: 1.6),
      ),
      child: done ? Icon(CupertinoIcons.checkmark, size: s * 0.62, color: c.bg) : null,
    );

Widget _tasks(WCtx c) {
  final items = app.store.list('tasks');
  final done = items.where((e) => e['done'] == true).length;
  final open = items.where((e) => e['done'] != true).toList();
  final ordered = [...open, ...items.where((e) => e['done'] == true)];
  final max = switch (c.size) { WSize.small => 3, WSize.medium => 4, WSize.large => 9 };
  final fs = c.sm ? 13.0 : 15.0;

  Widget row(Map<String, dynamic> t) => Padding(
        padding: EdgeInsets.symmetric(vertical: c.sm ? 3 : 4),
        child: Row(children: [
          _check(c, t['done'] == true, fs + 3),
          const SizedBox(width: 9),
          Expanded(
            child: Text('${t['t']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.t(fs, w: FontWeight.w500, dim: t['done'] == true, deco: t['done'] == true ? TextDecoration.lineThrough : null)),
          ),
        ]),
      );

  if (c.md) {
    return WShell(
      c: c,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 92,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tasks', style: c.t(15, dim: true)),
            const Spacer(),
            fit(Text('${open.length}', style: c.t(52, w: FontWeight.w600, h: 1))),
            Text('$done of ${items.length} done', style: c.t(12, dim: true)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [for (final t in ordered.take(max)) row(t)])),
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.sm ? 16 : 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.checkmark_circle, 'Tasks', trailing: '$done/${items.length}', size: c.lg ? 17 : null),
      if (c.lg) ...[const SizedBox(height: 10), GlowBar(c, items.isEmpty ? 0 : done / items.length, height: 6), const SizedBox(height: 8)],
      const SizedBox(height: 6),
      if (items.isEmpty) Expanded(child: Center(child: Text('All clear', style: c.script(30)))),
      for (final t in ordered.take(max)) row(t),
    ]),
  );
}

class _TasksEditor extends StatelessWidget {
  const _TasksEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final items = app.store.list('tasks');
          return Column(children: [
            ListEditor(
              title: 'Tasks',
              items: items,
              titleOf: (m) => '${m['t']}',
              addLabel: 'New task',
              footer: 'Tap to complete · swipe left to delete.',
              leading: (i) => GestureDetector(
                onTap: () => _toggle(items, i),
                child: Icon(items[i]['done'] == true ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                    color: items[i]['done'] == true ? K.green : K.label3, size: 24),
              ),
              onTap: (i) => _toggle(items, i),
              onAdd: () async {
                final t = await promptText(context, 'New task', placeholder: 'What needs doing?');
                if (t == null || t.isEmpty) return;
                app.store.set('tasks', [{'t': t, 'done': false}, ...items]);
              },
              onDelete: (i) => app.store.set('tasks', [...items]..removeAt(i)),
            ),
            if (items.any((e) => e['done'] == true))
              Section(children: [
                RowItem(
                  title: 'Clear completed',
                  destructive: true,
                  onTap: () => app.store.set('tasks', items.where((e) => e['done'] != true).toList()),
                ),
              ]),
          ]);
        },
      );

  void _toggle(List<Map<String, dynamic>> items, int i) {
    items[i]['done'] = !(items[i]['done'] == true);
    app.store.set('tasks', items);
  }
}

// ───────────────────────── 13 Habit ─────────────────────────

int _streak(List<String> days) {
  final set = days.toSet();
  var d = DateTime.now();
  if (!set.contains(dkey(d))) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (set.contains(dkey(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

Widget _habit(WCtx c) {
  final hs = app.store.list('habits');
  if (hs.isEmpty) return WEmpty(c, CupertinoIcons.flame, 'Add a habit to start a streak.', title: 'Habit');
  final now = DateTime.now();
  final week = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];

  Widget dots(List<String> days, double s) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (final d in week)
          Container(
            width: s,
            height: s,
            margin: EdgeInsets.only(left: s * 0.35),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: days.contains(dkey(d)) ? c.fg : c.faint,
              boxShadow: days.contains(dkey(d)) && dkey(d) == dkey(now) ? c.boxGlow(c.fg, 0.5) : null,
            ),
          ),
      ]);

  if (c.sm) {
    final h = hs.first;
    final days = (h['days'] as List? ?? []).map((e) => '$e').toList();
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.flame_fill, '${h['n']}'),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${_streak(days)}', style: c.t(54, w: FontWeight.w600, h: 1)),
          const SizedBox(width: 6),
          Text('day streak', style: c.t(13, dim: true)),
        ]),
        const SizedBox(height: 10),
        Transform.translate(offset: const Offset(-4, 0), child: dots(days, 13)),
      ]),
    );
  }
  final max = c.md ? 3 : 7;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Habits', style: c.t(c.lg ? 17 : 14, dim: true))),
        for (final d in week) SizedBox(width: (c.lg ? 14 : 11) * 1.35, child: Text(kDays[d.weekday - 1][0], textAlign: TextAlign.right, style: c.t(10, dim: true))),
      ]),
      for (final h in hs.take(max))
        Expanded(
          child: Row(children: [
            Expanded(child: Text('${h['n']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(c.lg ? 17 : 15))),
            Text('${_streak((h['days'] as List? ?? []).map((e) => '$e').toList())}', style: c.t(13, dim: true)),
            Icon(CupertinoIcons.flame_fill, size: 12, color: c.dim),
            dots((h['days'] as List? ?? []).map((e) => '$e').toList(), c.lg ? 14 : 11),
          ]),
        ),
    ]),
  );
}

class _HabitEditor extends StatelessWidget {
  const _HabitEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final hs = app.store.list('habits');
          final today = dkey(DateTime.now());
          bool doneToday(int i) => (hs[i]['days'] as List? ?? []).contains(today);
          return ListEditor(
            title: 'Today',
            items: hs,
            titleOf: (m) => '${m['n']}',
            subtitleOf: (m) => '${_streak((m['days'] as List? ?? []).map((e) => '$e').toList())} day streak',
            addLabel: 'New habit',
            footer: 'Tap to mark today as done.',
            leading: (i) => Icon(doneToday(i) ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                color: doneToday(i) ? K.green : K.label3, size: 24),
            onTap: (i) {
              final days = (hs[i]['days'] as List? ?? []).map((e) => '$e').toList();
              days.contains(today) ? days.remove(today) : days.add(today);
              hs[i]['days'] = days;
              app.store.set('habits', hs);
            },
            onAdd: () async {
              final t = await promptText(context, 'New habit', placeholder: 'e.g. Meditate');
              if (t == null || t.isEmpty) return;
              app.store.set('habits', [...hs, {'n': t, 'days': <String>[]}]);
            },
            onDelete: (i) => app.store.set('habits', [...hs]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 14 Notes ─────────────────────────

Widget _notes(WCtx c) {
  final text = app.store.str('notes.text');
  final at = app.store.n('notes.at', 0).toInt();
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 24 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.pencil_outline, 'Note', trailing: at == 0 ? null : ago(DateTime.fromMillisecondsSinceEpoch(at))),
      const SizedBox(height: 8),
      Expanded(
        child: Text(
          text.isEmpty ? 'Empty note' : text,
          overflow: TextOverflow.fade,
          style: c.t(c.sm ? 15 : (c.lg ? 22 : 17), w: FontWeight.w500, h: 1.3, dim: text.isEmpty),
        ),
      ),
    ]),
  );
}

class _NotesEditor extends StatelessWidget {
  const _NotesEditor();

  @override
  Widget build(BuildContext context) => Section(
        title: 'Note',
        footer: 'Saved automatically.',
        children: [
          FieldRow(
            initial: app.store.str('notes.text'),
            placeholder: 'Write something…',
            maxLines: 12,
            onChanged: (v) {
              app.store.set('notes.text', v);
              app.store.set('notes.at', DateTime.now().millisecondsSinceEpoch);
            },
          ),
        ],
      );
}

// ───────────────────────── 15 Schedule ─────────────────────────

List<(DateTime, String)> _plan() {
  final now = DateTime.now();
  final out = <(DateTime, String)>[];
  for (final e in app.store.list('schedule')) {
    final p = '${e['time']}'.split(':');
    if (p.length != 2) continue;
    out.add((DateTime(now.year, now.month, now.day, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0), '${e['t']}'));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

(DateTime, String)? nextEvent() {
  final now = DateTime.now();
  for (final e in _plan()) {
    if (e.$1.isAfter(now)) return e;
  }
  return null;
}

Widget _schedule(WCtx c) {
  final plan = _plan();
  final now = DateTime.now();
  final next = nextEvent();
  final h24 = app.settings.use24h;
  final upcoming = plan.where((e) => e.$1.isAfter(now)).toList();
  Widget line((DateTime, String) e, double fs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 3, height: fs + 4, decoration: BoxDecoration(color: e == next ? c.warm : c.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          SizedBox(width: fs * 3.4, child: Text(hm(e.$1, h24), style: c.t(fs, dim: true))),
          Expanded(child: Text(e.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(fs, dim: e.$1.isBefore(now)))),
        ]),
      );

  if (next == null) {
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.list_bullet, 'Schedule'),
        const Spacer(),
        Text('Day is done', style: c.script(c.sm ? 30 : 40)),
        Text(plan.isEmpty ? 'Add your daily plan' : '${plan.length} events completed', style: c.t(13, dim: true)),
      ]),
    );
  }
  final inStr = 'in ${dur(next.$1.difference(now), short: true)}';
  switch (c.size) {
    case WSize.small:
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, CupertinoIcons.list_bullet, 'Next'),
          const Spacer(),
          Text(next.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(22, h: 1.1)),
          const SizedBox(height: 4),
          Text('${hm(next.$1, h24)} · $inStr', style: c.t(13, dim: true)),
        ]),
      );
    case WSize.medium:
      return WShell(
        c: c,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WHeader(c, CupertinoIcons.list_bullet, 'Up next'),
              const Spacer(),
              Text(next.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.t(24, h: 1.1)),
              Text(inStr, style: c.t(14, c: c.warm)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [for (final e in upcoming.skip(1).take(4)) line(e, 13)])),
        ]),
      );
    case WSize.large:
      return WShell(
        c: c,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today', style: c.script(40)),
          Text('${kDays[now.weekday - 1]}, ${now.day} ${kMonths[now.month - 1]}', style: c.t(14, dim: true)),
          const SizedBox(height: 14),
          for (final e in plan.take(8)) line(e, 16),
          const Spacer(),
          Text('Next: ${next.$2} $inStr', style: c.t(14, c: c.warm)),
        ]),
      );
  }
}

class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final items = app.store.list('schedule')..sort((a, b) => '${a['time']}'.compareTo('${b['time']}'));
          return ListEditor(
            title: 'Daily plan',
            items: items,
            titleOf: (m) => '${m['t']}',
            subtitleOf: (m) => '${m['time']}',
            addLabel: 'Add event',
            footer: 'Repeats every day. Swipe left to delete.',
            onAdd: () async {
              final t = await promptText(context, 'Event', placeholder: 'e.g. Standup');
              if (t == null || t.isEmpty || !context.mounted) return;
              final d = await pickDateTime(context, mode: CupertinoDatePickerMode.time, use24h: app.settings.use24h);
              if (d == null) return;
              app.store.set('schedule', [...items, {'time': '${two(d.hour)}:${two(d.minute)}', 't': t}]);
            },
            onDelete: (i) => app.store.set('schedule', [...items]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 16 Progress ─────────────────────────

double _yearProgress() {
  final now = DateTime.now();
  final a = DateTime(now.year), b = DateTime(now.year + 1);
  return now.difference(a).inSeconds / b.difference(a).inSeconds;
}

Widget _progress(WCtx c) {
  final goals = [
    ('${DateTime.now().year}', _yearProgress()),
    for (final g in app.store.list('goals'))
      ('${g['n']}', ((g['v'] as num? ?? 0) / math.max(1, (g['max'] as num? ?? 1))).toDouble()),
  ];
  Widget bar((String, double) g, double fs, double h) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(g.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(fs, dim: true))),
          Text('${(g.$2 * 100).floor()}%', style: c.t(fs)),
        ]),
        SizedBox(height: h * 0.6),
        GlowBar(c, g.$2, height: h),
      ]);
  if (c.sm) {
    final g = goals.first;
    return WShell(
      c: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, CupertinoIcons.chart_bar_fill, g.$1 == '${DateTime.now().year}' ? 'Year progress' : g.$1),
        const Spacer(),
        fit(Text('${(g.$2 * 100).toStringAsFixed(1)}%', style: c.t(42, w: FontWeight.w600))),
        const SizedBox(height: 10),
        GlowBar(c, g.$2, height: 22, tick: true),
      ]),
    );
  }
  final max = c.md ? 3 : 6;
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.lg) ...[
        Text('Progress', style: c.script(40)),
        const SizedBox(height: 6),
      ],
      for (final g in goals.take(max)) Expanded(child: Center(child: bar(g, c.lg ? 15 : 13, c.lg ? 12 : 8))),
    ]),
  );
}

class _ProgressEditor extends StatelessWidget {
  const _ProgressEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final goals = app.store.list('goals');
          return Column(children: [
            for (var i = 0; i < goals.length; i++)
              Section(title: '${goals[i]['n']}', children: [
                StepperRow('Current', goals[i]['v'] as num? ?? 0, (v) {
                  goals[i]['v'] = v;
                  app.store.set('goals', goals);
                }, step: _stepFor(goals[i]['max'] as num? ?? 10), max: goals[i]['max'] as num? ?? 10),
                RowItem(
                  title: 'Target',
                  value: '${goals[i]['max']}',
                  onTap: () async {
                    final r = await promptText(context, 'Target', initial: '${goals[i]['max']}', keyboard: TextInputType.number);
                    final v = num.tryParse(r ?? '');
                    if (v == null || v <= 0) return;
                    goals[i]['max'] = v;
                    app.store.set('goals', goals);
                  },
                ),
                RowItem(title: 'Delete goal', destructive: true, onTap: () => app.store.set('goals', [...goals]..removeAt(i))),
              ]),
            Section(children: [
              RowItem(
                title: 'New goal',
                icon: CupertinoIcons.plus,
                iconColor: const Color(0xFF3A3A3C),
                chevron: false,
                onTap: () async {
                  final r = await promptFields(context, title: 'New goal', labels: ['Name', 'Target'], keyboards: [null, TextInputType.number]);
                  if (r == null || r[0].isEmpty) return;
                  app.store.set('goals', [...goals, {'n': r[0], 'v': 0, 'max': num.tryParse(r[1]) ?? 100}]);
                },
              ),
            ]),
          ]);
        },
      );

  num _stepFor(num max) => max >= 1000 ? 50 : (max >= 100 ? 5 : 1);
}

// ───────────────────────── 17 Time Tracker ─────────────────────────

int _secs(Map<String, dynamic> p) {
  final base = (p['sec'] as num? ?? 0).toInt();
  final run = p['run'] as num?;
  return run == null ? base : base + ((DateTime.now().millisecondsSinceEpoch - run) / 1000).floor();
}

String _hms(int s) => '${s ~/ 3600}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';

Widget _tracker(WCtx c) {
  Widget body() {
    final ps = app.store.list('tracker');
    if (ps.isEmpty) return WEmpty(c, CupertinoIcons.stopwatch, 'Add a project to track time.', title: 'Time Tracker');
    final running = ps.where((p) => p['run'] != null).firstOrNull;
    final total = ps.fold<int>(0, (a, p) => a + _secs(p));
    final maxS = ps.map(_secs).fold<int>(1, math.max);
    final head = running == null ? 'Not tracking' : '${running['n']}';
    final big = running == null ? _hms(total) : _hms(_secs(running));
    if (c.sm) {
      return WShell(
        c: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WHeader(c, running == null ? CupertinoIcons.stopwatch : CupertinoIcons.largecircle_fill_circle, head),
          const Spacer(),
          fit(Text(big, style: c.t(36, w: FontWeight.w600))),
          Text(running == null ? 'total tracked' : 'running', style: c.t(12, dim: true)),
        ]),
      );
    }
    return WShell(
      c: c,
      padding: EdgeInsets.all(c.lg ? 22 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WHeader(c, running == null ? CupertinoIcons.stopwatch : CupertinoIcons.largecircle_fill_circle, head, trailing: running == null ? null : 'live'),
        const SizedBox(height: 4),
        fit(Text(big, style: c.t(c.lg ? 54 : 36, w: FontWeight.w600))),
        const Spacer(),
        for (final p in ps.take(c.lg ? 6 : 2))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(width: 90, child: Text('${p['n']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: c.t(13, dim: p['run'] == null))),
              Expanded(child: GlowBar(c, _secs(p) / maxS, height: 6, color: p['run'] != null ? c.warm : c.fg)),
              SizedBox(width: 62, child: Text(dur(Duration(seconds: _secs(p)), short: true), textAlign: TextAlign.right, style: c.t(12, dim: true))),
            ]),
          ),
      ]),
    );
  }

  if (!c.live) return body();
  return ListenableBuilder(listenable: app.clock.second, builder: (context, _) => body());
}

class _TrackerEditor extends StatelessWidget {
  const _TrackerEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.store, app.clock.second]),
        builder: (context, _) {
          final ps = app.store.list('tracker');
          void toggle(int i) {
            final now = DateTime.now().millisecondsSinceEpoch;
            for (var j = 0; j < ps.length; j++) {
              if (ps[j]['run'] != null) {
                ps[j]['sec'] = _secs(ps[j]);
                final wasThis = j == i;
                ps[j].remove('run');
                if (wasThis) {
                  app.store.set('tracker', ps);
                  return;
                }
              }
            }
            ps[i]['run'] = now;
            app.store.set('tracker', ps);
          }

          return Column(children: [
            ListEditor(
              title: 'Projects',
              items: ps,
              titleOf: (m) => '${m['n']}',
              subtitleOf: (m) => _hms(_secs(m)),
              addLabel: 'New project',
              footer: 'Tap a project to start or stop. Only one runs at a time.',
              leading: (i) => Icon(ps[i]['run'] != null ? CupertinoIcons.stop_circle_fill : CupertinoIcons.play_circle_fill,
                  color: ps[i]['run'] != null ? K.red : K.label2, size: 26),
              onTap: toggle,
              onAdd: () async {
                final t = await promptText(context, 'Project', placeholder: 'e.g. Client work');
                if (t == null || t.isEmpty) return;
                app.store.set('tracker', [...ps, {'n': t, 'sec': 0}]);
              },
              onDelete: (i) => app.store.set('tracker', [...ps]..removeAt(i)),
            ),
            Section(children: [
              RowItem(
                title: 'Reset all times',
                destructive: true,
                onTap: () async {
                  if (!await confirm(context, 'Reset times?', 'All tracked time will be set to zero.', action: 'Reset')) return;
                  app.store.set('tracker', ps.map((p) => {'n': p['n'], 'sec': 0}).toList());
                },
              ),
            ]),
          ]);
        },
      );
}

// ───────────────────────── 18 Clipboard ─────────────────────────

Future<void> captureClipboard() async {
  try {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim();
    if (t == null || t.isEmpty) return;
    final list = app.store.strs('clips');
    if (list.isNotEmpty && list.first == t) return;
    list.remove(t);
    list.insert(0, t.length > 2000 ? t.substring(0, 2000) : t);
    app.store.set('clips', list.take(20).toList());
  } catch (_) {}
}

Widget _clipboard(WCtx c) {
  final clips = app.store.strs('clips');
  if (clips.isEmpty) return WEmpty(c, CupertinoIcons.doc_on_clipboard, 'Copy some text, then open So Widget.', title: 'Clipboard');
  final max = switch (c.size) { WSize.small => 2, WSize.medium => 3, WSize.large => 7 };
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 22 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WHeader(c, CupertinoIcons.doc_on_clipboard, 'Clipboard', trailing: '${clips.length}'),
      const SizedBox(height: 6),
      for (var i = 0; i < math.min(max, clips.length); i++)
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              clips[i].replaceAll('\n', ' '),
              maxLines: c.sm ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: c.t(i == 0 ? (c.sm ? 15 : 17) : 14, dim: i > 0, w: FontWeight.w500, h: 1.2),
            ),
          ),
        ),
    ]),
  );
}

class _ClipEditor extends StatelessWidget {
  const _ClipEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final clips = app.store.strs('clips');
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: PillButton('Save current clipboard', icon: CupertinoIcons.doc_on_clipboard, onTap: captureClipboard),
            ),
            ListEditor(
              title: 'History',
              items: [for (final t in clips) {'t': t}],
              titleOf: (m) => '${m['t']}'.replaceAll('\n', ' '),
              addLabel: 'Add text manually',
              footer: 'Copied text is saved automatically when you open the app. Tap to copy.',
              onTap: (i) {
                Clipboard.setData(ClipboardData(text: clips[i]));
                toast(context, 'Copied');
              },
              onAdd: () async {
                final t = await promptText(context, 'Add text');
                if (t == null || t.isEmpty) return;
                app.store.set('clips', [t, ...clips].take(20).toList());
              },
              onDelete: (i) => app.store.set('clips', [...clips]..removeAt(i)),
            ),
          ]);
        },
      );
}

// ───────────────────────── 19 Quick Links ─────────────────────────

Future<void> openUrl(String u) async {
  final uri = Uri.tryParse(u.contains('://') ? u : 'https://$u');
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Widget _links(WCtx c) {
  final ls = app.store.list('links');
  if (ls.isEmpty) return WEmpty(c, CupertinoIcons.link, 'Add your favorite sites.', title: 'Quick Links');
  final cols = c.sm ? 2 : 4;
  final max = switch (c.size) { WSize.small => 4, WSize.medium => 4, WSize.large => 12 };
  final items = ls.take(max).toList();
  Widget tile(Map<String, dynamic> l) => Tile(
        c,
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${l['l']}'.isEmpty ? '?' : '${l['l']}'.characters.first.toUpperCase(), style: c.t(c.md ? 30 : 24, w: FontWeight.w700)),
          const SizedBox(height: 4),
          fit(Text('${l['l']}', maxLines: 1, style: c.t(11, dim: true)), a: Alignment.center),
        ]),
      );
  if (c.md) {
    return WShell(
      c: c,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: tile(items[i]))],
      ]),
    );
  }
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.sm ? 14 : 16),
    child: GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: c.md ? 0.95 : 1,
      children: [
        for (final l in items)
          Tile(
            c,
            padding: const EdgeInsets.all(6),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${l['l']}'.isEmpty ? '?' : '${l['l']}'.characters.first.toUpperCase(), style: c.t(c.sm ? 22 : 26, w: FontWeight.w700)),
              const SizedBox(height: 2),
              fit(Text('${l['l']}', maxLines: 1, style: c.t(10, dim: true)), a: Alignment.center),
            ]),
          ),
      ],
    ),
  );
}

class _LinksEditor extends StatelessWidget {
  const _LinksEditor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (context, _) {
          final ls = app.store.list('links');
          return ListEditor(
            title: 'Links',
            items: ls,
            titleOf: (m) => '${m['l']}',
            subtitleOf: (m) => '${m['u']}',
            addLabel: 'Add link',
            footer: 'Tap to open. Swipe left to delete. Supports app links like spotify:// or tg://',
            onTap: (i) => openUrl('${ls[i]['u']}'),
            onAdd: () async {
              final r = await promptFields(context, title: 'New link', labels: ['Label', 'URL'], keyboards: [null, TextInputType.url]);
              if (r == null || r[1].isEmpty) return;
              app.store.set('links', [...ls, {'l': r[0].isEmpty ? Uri.tryParse(r[1])?.host ?? r[1] : r[0], 'u': r[1]}]);
            },
            onDelete: (i) => app.store.set('links', [...ls]..removeAt(i)),
          );
        },
      );
}

// ───────────────────────── 20 Daily Brief ─────────────────────────

Widget _brief(WCtx c) {
  final now = DateTime.now();
  final greet = now.hour < 5
      ? 'Good night'
      : now.hour < 12
          ? 'Good morning'
          : now.hour < 18
              ? 'Good afternoon'
              : 'Good evening';
  final w = Wx.now;
  final tasks = app.store.list('tasks').where((e) => e['done'] != true).length;
  final next = nextEvent();
  final fs = switch (c.size) { WSize.small => 15.0, WSize.medium => 17.0, WSize.large => 26.0 };
  InlineSpan b(String s) => TextSpan(text: s, style: c.t(fs, w: FontWeight.w600));
  InlineSpan d(String s) => TextSpan(text: s, style: c.t(fs, w: FontWeight.w600, dim: true));
  final spans = <InlineSpan>[
    d('It’s '),
    b('${kDays[now.weekday - 1]}, ${now.day} ${monShort(now)}. '),
    if (w != null) ...[b('${w.temp}°'), d(' and ${wmo(w.code, day: w.isDay).$1.toLowerCase()}, '), d('high '), b('${w.dMax.first}°. ')],
    b('$tasks task${tasks == 1 ? '' : 's'}'),
    d(' left'),
    if (next != null) ...[d(', next '), b(next.$2), d(' at ${hm(next.$1, app.settings.use24h)}.')] else d('.'),
  ];
  return WShell(
    c: c,
    padding: EdgeInsets.all(c.lg ? 26 : 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!c.sm) Text(greet, style: c.script(c.lg ? 46 : 30)),
      if (c.lg) const SizedBox(height: 10),
      Expanded(child: fit(SizedBox(width: c.dims.width - (c.lg ? 52 : 32), child: Text.rich(TextSpan(children: spans), style: c.t(fs, h: 1.25))), a: Alignment.topLeft)),
      if (c.lg && app.power.available)
        Row(children: [
          BatteryPill(c, app.power.level, app.power.charging),
          const Spacer(),
          Text(app.settings.city, style: c.t(13, dim: true)),
        ]),
    ]),
  );
}

// ───────────────────────── One-row glances ─────────────────────────

String _firstLine(String s, [int max = 60]) {
  final l = s.trim().split('\n').first.trim();
  return l.length > max ? '${l.substring(0, max)}…' : l;
}

final productivityGlances = <String, Glance Function(WCtx)>{
  'focus': (c) {
    final total = math.max(1, Focus.total);
    return Glance(_mmss(Focus.remaining),
        label: '${Focus.isBreak ? 'Break' : 'Focus'}${Focus.running ? '' : ' · paused'} · ${Focus.doneToday} today',
        icon: CupertinoIcons.timer,
        progress: 1 - Focus.remaining / total);
  },
  'tasks': (c) {
    final items = app.store.list('tasks');
    final open = items.where((e) => e['done'] != true).toList();
    return Glance(open.isEmpty ? 'All clear' : '${open.length} left',
        label: open.isEmpty ? '${items.length} done' : '${open.first['t']}',
        icon: CupertinoIcons.checkmark_circle_fill,
        progress: items.isEmpty ? null : (items.length - open.length) / items.length);
  },
  'habit': (c) {
    final hs = app.store.list('habits');
    if (hs.isEmpty) return const Glance('—', label: 'Add a habit', icon: CupertinoIcons.flame_fill);
    final today = dkey(DateTime.now());
    final done = hs.where((h) => (h['days'] as List? ?? []).contains(today)).length;
    final days = (hs.first['days'] as List? ?? []).map((e) => '$e').toList();
    return Glance('${_streak(days)} day streak', label: '${hs.first['n']} · $done of ${hs.length} done today', icon: CupertinoIcons.flame_fill, color: c.warm);
  },
  'notes': (c) {
    final t = app.store.str('notes.text');
    final lines = t.trim().split('\n');
    return Glance(t.isEmpty ? 'Empty note' : _firstLine(t),
        label: lines.length > 1 ? _firstLine(lines.skip(1).join(' ')) : 'Note', icon: CupertinoIcons.pencil_outline);
  },
  'schedule': (c) {
    final next = nextEvent();
    if (next == null) return const Glance('Day is done', label: 'No more events today', icon: CupertinoIcons.list_bullet);
    return Glance(next.$2,
        label: '${hm(next.$1, app.settings.use24h)} · in ${dur(next.$1.difference(DateTime.now()), short: true)}',
        icon: CupertinoIcons.list_bullet);
  },
  'progress': (c) {
    final y = _yearProgress();
    return Glance('${(y * 100).toStringAsFixed(1)}%', label: '${DateTime.now().year} progress', icon: CupertinoIcons.chart_bar_fill, progress: y);
  },
  'tracker': (c) {
    final ps = app.store.list('tracker');
    final running = ps.where((p) => p['run'] != null).firstOrNull;
    final total = ps.fold<int>(0, (a, p) => a + _secs(p));
    return Glance(running == null ? _hms(total) : _hms(_secs(running)),
        label: running == null ? 'Total tracked' : 'Tracking ${running['n']}', icon: CupertinoIcons.stopwatch_fill);
  },
  'clipboard': (c) {
    final clips = app.store.strs('clips');
    return Glance(clips.isEmpty ? 'Clipboard' : _firstLine(clips.first),
        label: '${clips.length} saved', icon: CupertinoIcons.doc_on_clipboard_fill);
  },
  'links': (c) {
    final ls = app.store.list('links');
    return Glance(ls.isEmpty ? 'Quick Links' : ls.take(4).map((l) => '${l['l']}').join(' · '), icon: CupertinoIcons.link);
  },
  'brief': (c) {
    final n = DateTime.now();
    final greet = n.hour < 5 ? 'Good night' : n.hour < 12 ? 'Good morning' : n.hour < 18 ? 'Good afternoon' : 'Good evening';
    final w = Wx.now;
    final tasks = app.store.list('tasks').where((e) => e['done'] != true).length;
    final next = nextEvent();
    return Glance(greet,
        label: [if (w != null) '${w.temp}°', '$tasks tasks', if (next != null) 'next ${next.$2}'].join(' · '),
        icon: CupertinoIcons.sun_haze_fill);
  },
};