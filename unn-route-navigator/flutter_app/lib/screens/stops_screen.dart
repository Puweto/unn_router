import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/route_map.dart';

/// "View Bus Stops / Locations" and "View Google Maps".
class StopsScreen extends StatelessWidget {
  final Reference reference;
  final Future<void> Function()? onRefresh;
  const StopsScreen({super.key, required this.reference, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    // Group shuttle segments by line name
    final lines = <String, Set<int>>{};
    for (final r in ref.routes) {
      final name = (r['route_name'] as String?) ?? 'Campus shuttle';
      lines.putIfAbsent(name, () => <int>{})..add(r['start_stop'] as int)..add(r['end_stop'] as int);
    }
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          'Campus map',
          RouteMap(
            stops: [for (final s in ref.stops) s.point],
            locations: [for (final l in ref.locations) l.point],
            namedRoutes: ref.namedRouteSegments,
            network: ref.routeLines,
            height: 380,
          ),
        ),
        _Section(
          'Shuttle lines',
          lines.isEmpty
              ? const Text('No shuttle lines have been added yet.')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final e in lines.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(e.value.map(ref.stopName).whereType<String>().join(' · ')),
                      ]),
                    ),
                ]),
        ),
        _Section('Bus stops (${ref.stops.length})', Column(children: [for (final s in ref.stops) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.directions_bus), title: Text(s.name))])),
        _Section('Locations (${ref.locations.length})', Column(children: [for (final l in ref.locations) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.place_outlined), title: Text(l.name))])),
      ],
    );
    return onRefresh == null ? content : RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section(this.title, this.child);
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}
