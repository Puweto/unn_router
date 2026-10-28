import 'dart:io';
import '../lib/config.dart';
import '../lib/db.dart';

void main() async {
  final envFile = File('.env');
  final env = <String, String>{};
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final idx = trimmed.indexOf('=');
      if (idx > 0) {
        env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
      }
    }
  }

  final cfg = Config.fromEnv();

  final db = Db(cfg);

  // 1. Ensure all essential Bus Stops exist
  final requiredStops = <(String, double, double)>[
    ('Main Gate Stop', 6.8617, 7.4032),
    ('Medical Centre Stop', 6.8656, 7.4062),
    ('Freedom Square Stop', 6.8676, 7.4092),
    ('Library Stop', 6.8686, 7.4117),
    ('Engineering Stop', 6.8716, 7.4142),
    ('Education Stop', 6.8726, 7.4082),
    ('SUB', 6.8665, 7.4075),
    ('Okpara Hostel', 6.8652, 7.4045),
    ('Odim Gate', 6.8595, 7.4010),
    ('Total Junction', 6.8525, 7.4005),
    ('Ogige Market Shuttle Park', 6.8512, 7.3998),
    ('Ziks Flat', 6.8717, 7.3983),
    ('UBA Hall of Fame', 6.8628, 7.4082),
    ('Eyoyita Hostel', 6.8631, 7.4096),
    ('Pharmacy', 6.8631, 7.4109),
    ('CEDR Hall', 6.8646, 7.4116),
    ('Vet', 6.8662, 7.4132),
    ('Hilltop Junction', 6.8695, 7.4145),
    ('Second Gate', 6.8678, 7.4172),
    ('Greenhouse', 6.8639, 7.4215),
  ];

  for (final (name, lat, lng) in requiredStops) {
    final existing = await db.get('SELECT stop_id FROM bus_stops WHERE stop_name = :n', {'n': name});
    if (existing == null) {
      print('Inserting missing bus stop: $name');
      await db.run('INSERT INTO bus_stops (stop_name, latitude, longitude) VALUES (:n, :a, :o)', {
        'n': name,
        'a': lat,
        'o': lng,
      });
    } else {
      await db.run('UPDATE bus_stops SET latitude = :a, longitude = :o WHERE stop_id = :id', {
        'a': lat,
        'o': lng,
        'id': existing['stop_id'],
      });
    }
  }

  // Get current stop IDs
  final stopRows = await db.all('SELECT stop_id, stop_name FROM bus_stops');
  final stopId = <String, int>{
    for (final r in stopRows) r['stop_name']!: int.parse(r['stop_id']!),
  };

  // 2. Comprehensive Shuttle Route Network (Bidirectional)
  final connections = <(String, String, String, double)>[
    // Campus Main Line
    ('Campus Main Line', 'Main Gate Stop', 'Medical Centre Stop', 0.68),
    ('Campus Main Line', 'Medical Centre Stop', 'SUB', 0.35),
    ('Campus Main Line', 'SUB', 'Freedom Square Stop', 0.22),
    ('Campus Main Line', 'Freedom Square Stop', 'Library Stop', 0.37),
    ('Campus Main Line', 'Library Stop', 'Engineering Stop', 0.54),
    ('Campus Main Line', 'SUB', 'UBA Hall of Fame', 0.52),
    ('Campus Main Line', 'UBA Hall of Fame', 'Eyoyita Hostel', 0.20),
    ('Campus Main Line', 'Eyoyita Hostel', 'Pharmacy', 0.18),
    ('Campus Main Line', 'Pharmacy', 'CEDR Hall', 0.23),
    ('Campus Main Line', 'CEDR Hall', 'Vet', 0.31),
    ('Campus Main Line', 'Vet', 'Hilltop Junction', 0.49),
    ('Campus Main Line', 'Hilltop Junction', 'Second Gate', 0.44),

    // Town Shuttle Line
    ('Town Shuttle', 'Ogige Market Shuttle Park', 'Total Junction', 0.20),
    ('Town Shuttle', 'Total Junction', 'Odim Gate', 0.98),
    ('Town Shuttle', 'Odim Gate', 'Main Gate Stop', 0.35),
    ('Town Shuttle', 'Odim Gate', 'Okpara Hostel', 0.93),
    ('Town Shuttle', 'Okpara Hostel', 'SUB', 0.45),

    // Ziks Flat Line
    ('Ziks Flat Line', 'Ziks Flat', 'Odim Gate', 1.74),
    ('Ziks Flat Line', 'Odim Gate', 'SUB', 1.32),

    // Education & Engineering Connectors
    ('Campus Main Line', 'Freedom Square Stop', 'Education Stop', 0.71),
    ('Campus Main Line', 'Education Stop', 'Engineering Stop', 0.84),

    // Agric Line
    ('Agric Line', 'CEDR Hall', 'Greenhouse', 1.37),
    ('Agric Line', 'Greenhouse', 'Second Gate', 0.80),
  ];

  // Clear old routes and insert clean, complete bidirectional network
  await db.run('DELETE FROM routes');

  for (final (line, fromName, toName, dist) in connections) {
    final s1 = stopId[fromName];
    final s2 = stopId[toName];
    if (s1 == null || s2 == null) {
      print('Warning: cannot find stops for $fromName ($s1) -> $toName ($s2)');
      continue;
    }
    // Forward direction
    await db.run('INSERT INTO routes (route_name, start_stop, end_stop, distance) VALUES (:l, :a, :b, :d)', {
      'l': line,
      'a': s1,
      'b': s2,
      'd': dist,
    });
    // Reverse direction
    await db.run('INSERT INTO routes (route_name, start_stop, end_stop, distance) VALUES (:l, :a, :b, :d)', {
      'l': line,
      'a': s2,
      'b': s1,
      'd': dist,
    });
  }

  final routeCount = await db.get('SELECT COUNT(*) AS c FROM routes');
  print('Successfully populated ${routeCount!["c"]} routes in the database!');
  exit(0);
}
