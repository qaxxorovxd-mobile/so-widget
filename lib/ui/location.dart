import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/state.dart';
import 'forms.dart';

/// Location + units section reused by weather-based widgets and Studio.
class LocationSection extends StatelessWidget {
  const LocationSection({super.key, this.showUnits = true, this.extraKeys = const []});
  final bool showUnits;

  /// Hub keys to refresh after a location change.
  final List<String> extraKeys;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.settings,
        builder: (context, _) {
          final s = app.settings;
          return Section(
            title: 'Location',
            footer: 'Used by weather, sun, air quality and prayer widgets.',
            children: [
              RowItem(
                icon: CupertinoIcons.location_fill,
                iconColor: K.blue,
                title: s.city,
                subtitle: '${s.country} · ${s.lat.toStringAsFixed(2)}, ${s.lon.toStringAsFixed(2)}',
                onTap: () => showSheet(context, const CitySearch(), title: 'Choose city'),
              ),
              if (showUnits)
                RowItem(
                  icon: CupertinoIcons.thermometer,
                  iconColor: const Color(0xFFFF9F0A),
                  title: 'Units',
                  trailing: SizedBox(
                    width: 130,
                    child: Seg<bool>(
                      value: s.metric,
                      items: const {true: '°C', false: '°F'},
                      onChanged: (v) => s.update(() => s.metric = v),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class CitySearch extends StatefulWidget {
  const CitySearch({super.key});

  @override
  State<CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<CitySearch> {
  List<Map<String, dynamic>> _results = [];
  bool _busy = false;
  String? _err;
  Timer? _deb;

  void _search(String q) {
    _deb?.cancel();
    if (q.trim().length < 2) return;
    _deb = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _busy = true;
        _err = null;
      });
      try {
        final r = await Api.geocode(q.trim());
        if (mounted) setState(() => _results = r);
      } catch (e) {
        if (mounted) setState(() => _err = 'Search failed. Check your connection.');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: CupertinoSearchTextField(
                autofocus: true,
                style: const TextStyle(color: K.label),
                backgroundColor: K.card,
                placeholder: 'Search city',
                onChanged: _search,
              ),
            ),
            if (_busy) const Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator()),
            if (_err != null) Padding(padding: const EdgeInsets.all(12), child: Text(_err!, style: const TextStyle(color: K.label2))),
            Expanded(
              child: ListView(
                children: [
                  Section(
                    children: [
                      for (final r in _results)
                        RowItem(
                          title: r['name'] as String? ?? '',
                          subtitle: [r['admin1'], r['country']].whereType<String>().join(', '),
                          onTap: () {
                            final s = app.settings;
                            s.update(() {
                              s.city = r['name'] as String? ?? s.city;
                              s.country = r['country'] as String? ?? '';
                              s.lat = (r['latitude'] as num).toDouble();
                              s.lon = (r['longitude'] as num).toDouble();
                            });
                            app.hub.invalidateAll();
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// "Refresh" row with last-updated info for a hub key.
class RefreshRow extends StatelessWidget {
  const RefreshRow(this.hubKey, {super.key, this.label = 'Refresh now'});
  final String hubKey;
  final String label;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.hub,
        builder: (context, _) {
          final at = app.hub.updated(hubKey);
          final err = app.hub.error(hubKey);
          final busy = app.hub.busy(hubKey);
          return Section(
            footer: err != null
                ? 'Last attempt failed: $err'
                : at == null
                    ? null
                    : 'Updated ${TimeOfDay.fromDateTime(at).format(context)}',
            children: [
              RowItem(
                icon: CupertinoIcons.arrow_clockwise,
                iconColor: const Color(0xFF3A3A3C),
                title: label,
                trailing: busy ? const CupertinoActivityIndicator(radius: 9) : null,
                chevron: false,
                onTap: busy ? null : () => app.hub.invalidate(hubKey),
              ),
            ],
          );
        },
      );
}
