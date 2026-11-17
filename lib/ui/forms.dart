import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// App chrome tokens (iOS dark grouped style).
class K {
  static const bg = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const card2 = Color(0xFF2C2C2E);
  static const sep = Color(0x22FFFFFF);
  static const label = Color(0xFFFFFFFF);
  static const label2 = Color(0x99EBEBF5);
  static const label3 = Color(0x4DEBEBF5);
  static const red = Color(0xFFFF453A);
  static const green = Color(0xFF30D158);
  static const blue = Color(0xFF0A84FF);
}

void tapFeedback() => HapticFeedback.selectionClick();

class Section extends StatelessWidget {
  const Section({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.padding,
  });
  final String? title;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 0.5, thickness: 0.5, color: K.sep),
          ),
        );
      }
    }
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: K.label2,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          if (items.isNotEmpty)
            ClipRSuperellipse(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: K.card,
                child: Column(children: items),
              ),
            ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(
                footer!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: K.label2,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RowItem extends StatelessWidget {
  const RowItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.value,
    this.onTap,
    this.destructive = false,
    this.chevron,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  final bool? chevron;

  @override
  Widget build(BuildContext context) {
    final showChevron = chevron ?? (onTap != null && trailing == null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                tapFeedback();
                onTap!();
              },
        highlightColor: Colors.white10,
        splashColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 29,
                    height: 29,
                    decoration: ShapeDecoration(
                      color: iconColor ?? K.card2,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Icon(icon, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: destructive ? K.red : K.label,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: K.label2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (value != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        value!,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13, color: K.label2),
                      ),
                    ),
                  ),
                ?trailing,
                if (showChevron)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color: K.label3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow(
    this.title,
    this.value,
    this.onChanged, {
    super.key,
    this.subtitle,
    this.icon,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => RowItem(
    title: title,
    subtitle: subtitle,
    icon: icon,
    trailing: CupertinoSwitch(
      value: value,
      activeTrackColor: K.green,
      onChanged: (v) {
        tapFeedback();
        onChanged(v);
      },
    ),
  );
}

class SliderRow extends StatelessWidget {
  const SliderRow(
    this.title,
    this.value,
    this.onChanged, {
    super.key,
    this.min = 0,
    this.max = 1,
    this.label,
    this.divisions,
  });
  final String title;
  final double value;
  final double min, max;
  final int? divisions;
  final String? label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, color: K.label),
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: const TextStyle(fontSize: 13, color: K.label2),
              ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Colors.white,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class StepperRow extends StatelessWidget {
  const StepperRow(
    this.title,
    this.value,
    this.onChanged, {
    super.key,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.format,
  });
  final String title;
  final num value;
  final num min, max, step;
  final String Function(num)? format;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) => RowItem(
    title: title,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          CupertinoIcons.minus,
          value > min ? () => onChanged((value - step).clamp(min, max)) : null,
        ),
        SizedBox(
          width: 64,
          child: Text(
            format?.call(value) ?? '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: K.label,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _btn(
          CupertinoIcons.plus,
          value < max ? () => onChanged((value + step).clamp(min, max)) : null,
        ),
      ],
    ),
  );

  Widget _btn(IconData i, VoidCallback? f) => GestureDetector(
    onTap: f == null
        ? null
        : () {
            tapFeedback();
            f();
          },
    child: Container(
      width: 44,
      height: 44,
      decoration: ShapeDecoration(
        color: K.card2,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      child: Icon(i, size: 16, color: f == null ? K.label3 : K.label),
    ),
  );
}

class Seg<T extends Object> extends StatelessWidget {
  const Seg({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: K.card,
      thumbColor: const Color(0xFF636366),
      children: items.map(
        (k, v) => MapEntry(
          k,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              v,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: K.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      onValueChanged: (v) {
        if (v != null) {
          tapFeedback();
          onChanged(v);
        }
      },
    ),
  );
}

class PillButton extends StatelessWidget {
  const PillButton(
    this.label, {
    super.key,
    this.icon,
    required this.onTap,
    this.filled = true,
    this.color,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (filled ? Colors.white : K.card2);
    final fg = filled && color == null ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: ShapeDecoration(
              color: bg,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline text field row with autosave.
class FieldRow extends StatefulWidget {
  const FieldRow({
    super.key,
    required this.initial,
    required this.onChanged,
    this.placeholder,
    this.maxLines = 1,
    this.keyboard,
    this.onSubmitted,
  });
  final String initial;
  final String? placeholder;
  final int maxLines;
  final TextInputType? keyboard;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<FieldRow> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoTextField(
    controller: _c,
    placeholder: widget.placeholder,
    maxLines: widget.maxLines,
    minLines: widget.maxLines > 1 ? 3 : 1,
    keyboardType: widget.keyboard,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    style: const TextStyle(fontSize: 14, color: K.label, height: 1.35),
    placeholderStyle: const TextStyle(fontSize: 14, color: K.label3),
    cursorColor: Colors.white,
    decoration: const BoxDecoration(color: Colors.transparent),
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
  );
}

Future<T?> showSheet<T>(BuildContext context, Widget child, {String? title}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    backgroundColor: const Color(0xFF111113),
    shape: const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: K.label3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: K.label,
                  ),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    ),
  );
}

Future<List<String>?> promptFields(
  BuildContext context, {
  required String title,
  required List<String> labels,
  List<String>? initial,
  List<TextInputType?>? keyboards,
  String action = 'Save',
}) {
  final ctrls = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(
        text: initial != null && i < initial.length ? initial[i] : '',
      ),
  ];
  return showCupertinoDialog<List<String>>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: CupertinoTextField(
                  controller: ctrls[i],
                  placeholder: labels[i],
                  autofocus: i == 0,
                  keyboardType: keyboards != null && i < keyboards.length
                      ? keyboards[i]
                      : null,
                  style: const TextStyle(color: K.label),
                ),
              ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.pop(ctx, ctrls.map((e) => e.text.trim()).toList()),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}

Future<String?> promptText(
  BuildContext context,
  String title, {
  String initial = '',
  String placeholder = '',
  TextInputType? keyboard,
}) async {
  final r = await promptFields(
    context,
    title: title,
    labels: [placeholder],
    initial: [initial],
    keyboards: [keyboard],
  );
  return r?.first;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Delete',
}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDateTime(
  BuildContext context, {
  DateTime? initial,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
  bool use24h = true,
}) {
  var value = initial ?? DateTime.now();
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.dark),
      child: Container(
        height: 320,
        color: const Color(0xFF1C1C1E),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  CupertinoButton(
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.pop(ctx, value),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: mode,
                  use24hFormat: use24h,
                  initialDateTime: value,
                  onDateTimeChanged: (d) => value = d,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(milliseconds: 1600),
      ),
    );
}

/// Editable list helper used by many widget editors.
class ListEditor extends StatelessWidget {
  const ListEditor({
    super.key,
    required this.title,
    required this.items,
    required this.titleOf,
    this.subtitleOf,
    required this.onAdd,
    required this.onDelete,
    this.onTap,
    this.leading,
    this.trailing,
    this.addLabel = 'Add',
    this.footer,
  });
  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>)? subtitleOf;
  final VoidCallback onAdd;
  final void Function(int) onDelete;
  final void Function(int)? onTap;
  final Widget Function(int)? leading;
  final Widget Function(int)? trailing;
  final String addLabel;
  final String? footer;

  @override
  Widget build(BuildContext context) => Section(
    title: title,
    footer: footer,
    children: [
      for (var i = 0; i < items.length; i++)
        Dismissible(
          key: ValueKey('${items[i].hashCode}-$i-${titleOf(items[i])}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: K.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(CupertinoIcons.delete, color: Colors.white),
          ),
          onDismissed: (_) => onDelete(i),
          child: Row(
            children: [
              if (leading != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: leading!(i),
                ),
              Expanded(
                child: RowItem(
                  title: titleOf(items[i]),
                  subtitle: subtitleOf?.call(items[i]),
                  onTap: onTap == null ? null : () => onTap!(i),
                  trailing: trailing?.call(i),
                  chevron: false,
                ),
              ),
            ],
          ),
        ),
      RowItem(
        title: addLabel,
        icon: CupertinoIcons.plus,
        iconColor: const Color(0xFF3A3A3C),
        onTap: onAdd,
        chevron: false,
      ),
    ],
  );
}
