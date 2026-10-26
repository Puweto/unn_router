import 'auth.dart';
import 'config.dart';
import 'db.dart';
import 'geo.dart';

// SAMPLE DATA. Names are real campus landmarks, but the coordinates are APPROXIMATE
// PLACEHOLDERS (around 6.8673 N, 7.4085 E) and the shuttle lines are illustrative.
// The Director of Transport must correct them with the admin dashboard ("Pick on map").
const _dLat = 0.0075, _dLng = 0.002; // shifts the sample points onto the Nsukka campus area

const _locations = <(String, double, double)>[
  ('Main Gate', 6.8540, 7.4010),
  ('Odim Gate', 6.8520, 7.3990),
  ('Medical Centre', 6.8580, 7.4040),
  ('Students Union Building', 6.8590, 7.4055),
  ('Freedom Square', 6.8600, 7.4070),
  ('Princess Alexandra Auditorium', 6.8595, 7.4085),
  ('Nnamdi Azikiwe Library', 6.8610, 7.4095),
  ('Faculty of Law', 6.8570, 7.4100),
  ('Faculty of Physical Sciences', 6.8625, 7.4105),
  ('Faculty of Engineering', 6.8640, 7.4120),
  ('Faculty of Education', 6.8650, 7.4060),
  ('Hilltop Hostels', 6.8670, 7.4140),
];

const _stops = <(String, double, double)>[
  ('Odim Gate Stop', 6.8522, 7.3992),
  ('Main Gate Stop', 6.8542, 7.4012),
  ('Medical Centre Stop', 6.8581, 7.4042),
  ('Freedom Square Stop', 6.8601, 7.4072),
  ('Library Stop', 6.8611, 7.4097),
  ('Engineering Stop', 6.8641, 7.4122),
  ('Hilltop Stop', 6.8671, 7.4142),
  ('Education Stop', 6.8651, 7.4062),
];

const _lineA = 'Line A (Main Gate - Hilltop)';
const _lineB = 'Line B (Odim Gate - Education)';
const _routeLinks = <(String, String, String)>[
  (_lineA, 'Main Gate Stop', 'Medical Centre Stop'),
  (_lineA, 'Medical Centre Stop', 'Freedom Square Stop'),
  (_lineA, 'Freedom Square Stop', 'Library Stop'),
  (_lineA, 'Library Stop', 'Engineering Stop'),
  (_lineA, 'Engineering Stop', 'Hilltop Stop'),
  (_lineB, 'Odim Gate Stop', 'Main Gate Stop'),
  (_lineB, 'Main Gate Stop', 'Freedom Square Stop'),
  (_lineB, 'Freedom Square Stop', 'Education Stop'),
  (_lineB, 'Education Stop', 'Engineering Stop'),
];

Future<void> seed(Db db, Config cfg) async {
  final count = await db.get('SELECT COUNT(*) AS n FROM locations');
  if (int.parse(count!['n']!) == 0) {
    final locId = <String, int>{}, stopId = <String, int>{};
    final pos = <String, (double, double)>{};
    for (final (name, lat, lng) in _locations) {
      final r = await db.run('INSERT INTO locations (location_name, latitude, longitude) VALUES (:n,:a,:o)', {'n': name, 'a': lat + _dLat, 'o': lng + _dLng});
      locId[name] = r.insertId;
      pos['L$name'] = (lat + _dLat, lng + _dLng);
    }
    for (final (name, lat, lng) in _stops) {
      final r = await db.run('INSERT INTO bus_stops (stop_name, latitude, longitude) VALUES (:n,:a,:o)', {'n': name, 'a': lat + _dLat, 'o': lng + _dLng});
      stopId[name] = r.insertId;
      pos['S$name'] = (lat + _dLat, lng + _dLng);
    }
    double km(String a, String b) => roadEstimateKm(pos[a]!.$1, pos[a]!.$2, pos[b]!.$1, pos[b]!.$2);
    for (final (line, a, b) in _routeLinks) {
      await db.run('INSERT INTO routes (route_name, start_stop, end_stop, distance) VALUES (:l,:a,:b,:d)',
          {'l': line, 'a': stopId[a], 'b': stopId[b], 'd': km('S$a', 'S$b')});
    }
  }

  final d = await db.get('SELECT directorId FROM director_of_transport WHERE username = :u', {'u': cfg.directorUsername});
  if (d == null) {
    final pw = cfg.directorPassword ?? 'director123';
    await db.run('INSERT INTO director_of_transport (username, password) VALUES (:u,:p)', {'u': cfg.directorUsername, 'p': hashPassword(pw)});
    if (cfg.directorPassword == null) {
      // ignore: avoid_print
      print('[seed] Director account "${cfg.directorUsername}" created with the DEFAULT password. Set DIRECTOR_PASSWORD before real use.');
    }
  }
}
