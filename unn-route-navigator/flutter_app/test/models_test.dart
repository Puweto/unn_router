import 'package:flutter_test/flutter_test.dart';
import 'package:unn_route_navigator/models.dart';

void main() {
  test('formatKm switches between metres and kilometres', () {
    expect(formatKm(0.031), '31 m');
    expect(formatKm(3.03), '3.03 km');
  });

  test('Place parses API rows', () {
    final p = Place.location({'location_id': 3, 'location_name': 'Main Gate', 'latitude': 6.86, 'longitude': 7.41});
    expect(p.id, 3);
    expect(p.point.name, 'Main Gate');
    final s = Place.stop({'stop_id': 1, 'stop_name': 'Main Gate Stop', 'latitude': 6.86, 'longitude': 7.41});
    expect(s.name, 'Main Gate Stop');
  });

  test('formatWhen turns a server UTC timestamp into a readable local time', () {
    expect(formatWhen('not a date'), 'not a date');
    expect(formatWhen('2026-10-05 11:20:00').length, 16); // yyyy-MM-dd HH:mm
  });
}
