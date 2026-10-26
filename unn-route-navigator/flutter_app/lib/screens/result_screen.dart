import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets/route_map.dart';

/// Output design (Fig 3.5): "Route successfully found", map, Estimated Distance,
/// Estimated Time, Bus Stops.
class ResultScreen extends StatelessWidget {
  final RouteResult result;
  final Reference reference;
  const ResultScreen({super.key, required this.result, required this.reference});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route result'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((x) => x.isFirst);
              Session.end();
            },
            child: const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!r.found) ...[
            _Banner(text: 'No route found. ${r.reason ?? ''}', color: scheme.error),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Try another search')),
          ] else ...[
            const _Banner(text: 'Route successfully found', color: Color(0xFF0B5D34)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.origin} → ${r.destination}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: r.mode == 'bus'
                        ? [
                            for (final l in r.lines)
                              Chip(label: Text(l), backgroundColor: const Color(0xFFF5C542), labelStyle: const TextStyle(color: Color(0xFF3A2D00), fontWeight: FontWeight.w700)),
                          ]
                        : const [Chip(label: Text('On foot'), backgroundColor: Color(0xFFF5C542))]),
                    const SizedBox(height: 12),
                    RouteMap(
                      path: r.path,
                      stops: r.busStops,
                      locations: [for (final l in reference.locations) l.point],
                      namedRoutes: reference.namedRouteSegments,
                      network: reference.routeLines,
                      pathLines: r.lines,
                      walkingTimeMin: r.directWalkMin ?? r.timeMin,
                      height: 360,
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.mode == 'bus') ...[
                      Row(children: [
                        Expanded(
                          child: _Stat(
                            'Est. Shuttle Time',
                            '${r.timeMin} min',
                            icon: Icons.directions_bus,
                            subtitle: 'Shuttle ride + walk to stops',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            'Est. Walking Time',
                            '${r.directWalkMin ?? r.timeMin} min',
                            icon: Icons.directions_walk,
                            subtitle: 'Walk between ${r.origin} & ${r.destination}',
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _Stat(
                            'Shuttle Route Distance',
                            formatKm(r.distanceKm),
                            icon: Icons.route,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            'Direct Walking Distance',
                            formatKm(r.directKm ?? r.distanceKm),
                            icon: Icons.straighten,
                          ),
                        ),
                      ]),
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF1565C0)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estimated walking time directly between your location (${r.origin}) and destination (${r.destination}) is about ${r.directWalkMin ?? r.timeMin} min (${formatKm(r.directKm ?? r.distanceKm)}) on foot.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(children: [
                        Expanded(
                          child: _Stat(
                            'Estimated Distance',
                            formatKm(r.distanceKm),
                            icon: Icons.straighten,
                            subtitle: 'Campus walking path',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            'Estimated Walking Time',
                            '${r.timeMin} min',
                            icon: Icons.directions_walk,
                            subtitle: 'Walk between ${r.origin} & ${r.destination}',
                          ),
                        ),
                      ]),
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B5D34).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0B5D34).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.directions_walk, size: 16, color: Color(0xFF0B5D34)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estimated walking time between your location (${r.origin}) and destination (${r.destination}) is about ${r.timeMin} min (calculated at an average campus walking pace of 5 km/h).',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0B5D34), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Directions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    for (var i = 0; i < r.steps.length; i++)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${i + 1}. ${r.steps[i]}')),
                    if (r.mode == 'bus' && r.directKm != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Walking the whole way instead: ${formatKm(r.directKm!)}, about ${r.directWalkMin} min.', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ),
            if (r.busStops.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bus Stops', style: Theme.of(context).textTheme.titleMedium),
                      for (var i = 0; i < r.busStops.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(r.busStops[i].name),
                          trailing: Text(i == 0 ? 'Board' : i == r.busStops.length - 1 ? 'Alight' : 'Stop $i', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              ),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('New search')),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), border: Border.all(color: color.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final String? subtitle;
  final IconData? icon;

  const _Stat(this.label, this.value, {this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
}
