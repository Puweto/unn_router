import 'package:flutter_test/flutter_test.dart';
import 'package:unn_route_navigator/models.dart';
import 'package:unn_route_navigator/routing.dart';

Place loc(int id, String n, double lat, double lng) => Place(id, n, lat, lng);

void main() {
  test('dijkstra finds the shortest path, not the fewest hops', () {
    final g = buildGraph(const [
      GraphEdge(1, 2, 1, 'a'),
      GraphEdge(2, 3, 1, 'b'),
      GraphEdge(1, 3, 5, 'c'),
      GraphEdge(3, 4, 1, 'd'),
    ]);
    final r = dijkstra(g, 1, 4)!;
    expect(r.nodes, [1, 2, 3, 4]);
    expect(r.distance, 3);
    expect(r.edges, ['a', 'b', 'd']);
  });

  test('dijkstra: unreachable, same node, unknown node', () {
    final g = buildGraph(const [GraphEdge(1, 2, 1), GraphEdge(8, 9, 1)]);
    expect(dijkstra(g, 1, 9), isNull);
    expect(dijkstra(g, 1, 1)!.distance, 0);
    expect(dijkstra(g, 1, 77), isNull);
  });

  test('haversine: 0.01 degree of latitude is about 1.11 km', () {
    expect(haversineKm(6.85, 7.4, 6.86, 7.4), closeTo(1.112, 0.01));
  });

  final a = loc(1, 'A', 6.850, 7.400), b = loc(2, 'B', 6.870, 7.400), island = loc(3, 'Island', 6.900, 7.500);
  final ref = Reference(
    [a, b, island],
    [loc(1, 'SA', 6.8501, 7.4), loc(2, 'SM', 6.860, 7.4), loc(3, 'SB', 6.8701, 7.4)],
    [
      {'route_name': 'L1', 'start_stop': 1, 'end_stop': 2, 'distance': 1.2},
      {'route_name': 'L2', 'start_stop': 2, 'end_stop': 3, 'distance': 1.2},
    ],
  );

  test('long trip: recommends the bus, merges legs per line, lists the stops', () {
    final r = planJourney(Origin.fromPlace(a), b, ref);
    expect(r.found, isTrue);
    expect(r.mode, 'bus');
    expect(r.lines, ['L1', 'L2']);
    expect(r.busStops.map((s) => s.name), ['SA', 'SM', 'SB']);
    expect(r.timeMin, lessThan(30));
    expect(r.distanceKm, greaterThan(2.4));
    expect(r.path.first.name, 'A');
    expect(r.path.last.name, 'B');
  });

  test('GPS origin near A gives the same shuttle journey', () {
    final r = planJourney(const Origin('My location', 6.8501, 7.4), b, ref);
    expect(r.mode, 'bus');
    expect(r.origin, 'My location');
    expect(r.busStops.first.name, 'SA');
  });

  test('no stops nearby: falls back to walking (straight line x 1.25)', () {
    final noBus = Reference(ref.locations, const [], const []);
    final r = planJourney(Origin.fromPlace(a), b, noBus);
    expect(r.found, isTrue);
    expect(r.mode, 'walk');
    expect(r.distanceKm, closeTo(2.78, 0.02));
    expect(r.path.length, 2);
  });

  test('a place far from every stop is reached on foot, not by shuttle', () {
    final r = planJourney(Origin.fromPlace(a), island, ref);
    expect(r.found, isTrue);
    expect(r.mode, 'walk');
    expect(r.busStops, isEmpty);
  });
}
