import 'dart:math' as math;
import 'models.dart';

// Constants used for the time estimates (adjust to the real shuttle service).
const double walkKmh = 5;
const double busKmh = 20;
const double busWaitMin = 5; // average wait per shuttle line
const double maxWalkToStopKm = 1.5;
const double roadFactor = 1.25; // road length / straight-line distance

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

class GraphEdge {
  final int from, to;
  final double distance;
  final String meta; // shuttle line name
  const GraphEdge(this.from, this.to, this.distance, [this.meta = '']);
}

class _Arc {
  final int to;
  final double distance;
  final String meta;
  const _Arc(this.to, this.distance, this.meta);
}

typedef Graph = Map<int, List<_Arc>>;

/// Edges are undirected: shuttles run in both directions.
Graph buildGraph(Iterable<GraphEdge> edges) {
  final g = <int, List<_Arc>>{};
  for (final e in edges) {
    g.putIfAbsent(e.from, () => []).add(_Arc(e.to, e.distance, e.meta));
    g.putIfAbsent(e.to, () => []).add(_Arc(e.from, e.distance, e.meta));
  }
  return g;
}

class PathResult {
  final double distance;
  final List<int> nodes;
  final List<String> edges; // meta of each hop
  const PathResult(this.distance, this.nodes, this.edges);
}

/// Dijkstra's shortest path algorithm. Returns null when dst cannot be reached from src.
PathResult? dijkstra(Graph graph, int src, int dst) {
  if (src == dst) return PathResult(0, [src], const []);
  if (!graph.containsKey(src) || !graph.containsKey(dst)) return null;
  final dist = <int, double>{src: 0};
  final prev = <int, (int, String)>{};
  final done = <int>{};
  final queue = <(double, int)>[(0, src)]; // campus graphs are tiny: a sorted list is plenty
  while (queue.isNotEmpty) {
    queue.sort((a, b) => a.$1.compareTo(b.$1));
    final (d, u) = queue.removeAt(0);
    if (!done.add(u)) continue;
    if (u == dst) break;
    for (final arc in graph[u] ?? const <_Arc>[]) {
      final nd = d + arc.distance;
      if (nd < (dist[arc.to] ?? double.infinity)) {
        dist[arc.to] = nd;
        prev[arc.to] = (u, arc.meta);
        queue.add((nd, arc.to));
      }
    }
  }
  if (!dist.containsKey(dst)) return null;
  final nodes = <int>[dst];
  final edges = <String>[];
  var cur = dst;
  while (prev.containsKey(cur)) {
    final p = prev[cur]!;
    edges.insert(0, p.$2);
    nodes.insert(0, p.$1);
    cur = p.$1;
  }
  return PathResult(dist[dst]!, nodes, edges);
}

/// Closest place to a point, with its straight-line distance in km. Null if the list is empty.
(Place, double)? nearestPlace(double lat, double lng, List<Place> places) {
  (Place, double)? best;
  for (final p in places) {
    final d = haversineKm(lat, lng, p.lat, p.lng);
    if (best == null || d < best.$2) best = (p, d);
  }
  return best;
}

double _round(double n, [int places = 2]) {
  final f = math.pow(10, places).toDouble();
  return (n * f).round() / f;
}

double _minutes(double km, double kmh) => km / kmh * 60;

/// Finds the best way from [origin] to [destination]: ride the shuttle network (walk to the nearest
/// stop, ride along the shortest shuttle path found with Dijkstra, walk on) or walk, whichever is quicker.
RouteResult planJourney(Origin origin, Place destination, Reference ref) {
  // ----- walking the whole way (straight-line distance x road factor) -----
  final directKm = _round(haversineKm(origin.lat, origin.lng, destination.lat, destination.lng) * roadFactor);
  final directWalkMin = _minutes(directKm, walkKmh).round();

  // ----- shuttle option -----
  final from = nearestPlace(origin.lat, origin.lng, ref.stops);
  final to = nearestPlace(destination.lat, destination.lng, ref.stops);
  if (from != null && to != null && from.$2 <= maxWalkToStopKm && to.$2 <= maxWalkToStopKm && from.$1.id != to.$1.id) {
    final routeGraph = buildGraph([
      for (final r in ref.routes)
        GraphEdge(r['start_stop'] as int, r['end_stop'] as int, (r['distance'] as num).toDouble(), (r['route_name'] as String?) ?? 'Campus shuttle'),
    ]);
    final ride = dijkstra(routeGraph, from.$1.id, to.$1.id);
    if (ride != null) {
      final stopById = {for (final s in ref.stops) s.id: s};
      final rideStops = [for (final id in ride.nodes) stopById[id]!];
      // Merge consecutive hops on the same line into one leg
      final legs = <({String line, Place from, Place to, int hops})>[];
      for (var i = 0; i < ride.edges.length; i++) {
        final line = ride.edges[i];
        if (legs.isNotEmpty && legs.last.line == line) {
          final last = legs.removeLast();
          legs.add((line: line, from: last.from, to: rideStops[i + 1], hops: last.hops + 1));
        } else {
          legs.add((line: line, from: rideStops[i], to: rideStops[i + 1], hops: 1));
        }
      }
      final walkKm = from.$2 + to.$2;
      final timeMin = (_minutes(walkKm, walkKmh) + _minutes(ride.distance, busKmh) + busWaitMin * legs.length).round();
      final prefersBus = origin.isBusStop || destination.isBusStop;
      if (timeMin < directWalkMin || (prefersBus && directKm >= 0.4)) {
        final steps = <String>[];
        if (from.$2 > 0.03) {
          steps.add('Walk about ${(from.$2 * 1000).round()} m from ${origin.name} to ${legs.first.from.name} bus stop.');
        } else {
          steps.add('You are at ${legs.first.from.name} bus stop.');
        }

        for (final l in legs) {
          steps.add('Board ${l.line} at ${l.from.name} and ride ${l.hops} stop${l.hops > 1 ? "s" : ""} to ${l.to.name}.');
        }

        if (to.$2 > 0.03) {
          steps.add('Walk about ${(to.$2 * 1000).round()} m from ${legs.last.to.name} bus stop to ${destination.name}.');
        } else {
          steps.add('Alight at ${legs.last.to.name} bus stop (your destination).');
        }

        final rawPath = [origin.point, for (final s in rideStops) s.point, destination.point];
        final cleanPath = <MapPoint>[];
        for (final p in rawPath) {
          if (cleanPath.isEmpty || cleanPath.last.name != p.name) {
            cleanPath.add(p);
          }
        }

        return RouteResult(
          found: true,
          origin: origin.name,
          destination: destination.name,
          mode: 'bus',
          distanceKm: _round(ride.distance + walkKm),
          timeMin: timeMin,
          steps: steps,
          lines: {for (final l in legs) l.line}.toList(),
          busStops: [for (final s in rideStops) s.point],
          path: cleanPath,
          directKm: directKm,
          directWalkMin: directWalkMin,
        );
      }
    }
  }

  return RouteResult(
    found: true,
    origin: origin.name,
    destination: destination.name,
    mode: 'walk',
    distanceKm: directKm,
    timeMin: directWalkMin,
    steps: ['No shuttle saves you time on this trip. Walk from ${origin.name} to ${destination.name} (about ${(directKm * 1000).round()} m).'],
    path: [origin.point, destination.point],
    directKm: directKm,
    directWalkMin: directWalkMin,
  );
}
