import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/registry.dart';
import '../core/style.dart';
import '../ui/forms.dart';

Future<WDef?> pickWidget(BuildContext context, WSize size, {String? current}) =>
    showSheet<WDef>(
      context,
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: WidgetPicker(size: size, current: current),
      ),
      title: 'Choose ${size.label.toLowerCase()} widget',
    );

class WidgetPicker extends StatefulWidget {
  const WidgetPicker({super.key, required this.size, this.current});
  final WSize size;
  final String? current;

  @override
  State<WidgetPicker> createState() => _WidgetPickerState();
}

class _WidgetPickerState extends State<WidgetPicker> {
  String _query = '';
  WCat? _category;
  late WDef? _selected = widgetById[widget.current];

  @override
  Widget build(BuildContext context) {
    final list = allWidgets
        .where(
          (d) =>
              (_category == null || d.cat == _category) &&
              '${d.name} ${d.desc} ${d.cat.label} ${d.number}'
                  .toLowerCase()
                  .contains(_query),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CupertinoSearchTextField(
              placeholder: 'Search name, category or number',
              style: const TextStyle(fontSize: 14, color: K.label),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          if (bounds.maxHeight > 350)
            SizedBox(
              height: 44 + MediaQuery.textScalerOf(context).scale(12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final cat in <WCat?>[null, ...WCat.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 8),
                      child: Semantics(
                        selected: _category == cat,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: _category == cat ? K.card2 : K.card,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => setState(() => _category = cat),
                          child: Text(
                            cat?.label ?? 'All',
                            style: const TextStyle(
                              fontSize: 12,
                              color: K.label,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_selected != null &&
              bounds.maxHeight > 480 &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: FittedBox(
                  child: IgnorePointer(
                    child: WidgetFace(_selected!, widget.size),
                  ),
                ),
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'No widgets found. Try another search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: K.label2),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final d = list[i];
                      final selected = _selected?.id == d.id;
                      return Semantics(
                        selected: selected,
                        child: RowItem(
                          title: d.name,
                          subtitle:
                              '${d.cat.label}${d.id == widget.current ? ' · Current widget' : ''}',
                          icon: d.icon,
                          iconColor: selected ? K.green : K.card2,
                          trailing: Icon(
                            selected
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            size: 22,
                            color: selected ? K.green : K.label3,
                          ),
                          onTap: () => setState(() => _selected = d),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: PillButton(
                    'Cancel',
                    filled: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PillButton(
                    'Use widget',
                    onTap: _selected == null
                        ? null
                        : () => Navigator.pop(context, _selected),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
