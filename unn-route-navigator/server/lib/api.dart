import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'auth.dart';
import 'config.dart';
import 'db.dart';
import 'geo.dart';

class HttpError implements Exception {
  final int status;
  final String message;
  HttpError(this.status, this.message);
}

HttpError _bad(String m) => HttpError(400, m);

/// The MySQL driver substitutes :name placeholders in the SQL text, so keep ':' out of user-supplied text.
String _safe(String s) => s.replaceAll(':', '-');

const _intCols = {'user_id', 'history_id', 'directorId', 'location_id', 'stop_id', 'route_id', 'start_stop', 'end_stop'};
const _doubleCols = {'latitude', 'longitude', 'distance'};

/// The MySQL driver returns every value as text; convert known columns to numbers.
Map<String, dynamic> typed(Map<String, String?> row) => {
      for (final e in row.entries)
        e.key: e.value == null
            ? null
            : _intCols.contains(e.key)
                ? int.parse(e.value!)
                : _doubleCols.contains(e.key)
                    ? double.parse(e.value!)
                    : e.value,
    };

class _Resource {
  final String table, pk, order;
  final Map<String, String> fields; // column -> kind
  const _Resource(this.table, this.pk, this.order, this.fields);
}

// Director of Transport: Manage Locations / Bus Stops / Bus Routes
const _resources = <String, _Resource>{
  'locations': _Resource('locations', 'location_id', 'location_name', {'location_name': 'name', 'latitude': 'lat', 'longitude': 'lng'}),
  'bus-stops': _Resource('bus_stops', 'stop_id', 'stop_name', {'stop_name': 'name', 'latitude': 'lat', 'longitude': 'lng'}),
  'routes': _Resource('routes', 'route_id', 'route_id', {'route_name': 'optname', 'start_stop': 'id', 'end_stop': 'id', 'distance': 'kmopt'}),
};

dynamic _clean(String kind, dynamic v, String field) {
  num? asNum() => v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
  final isBlank = v == null || (v is String && v.trim().isEmpty);
  if (kind == 'name') {
    if (v is! String || v.trim().isEmpty || v.trim().length > 100) throw _bad('$field is required (max 100 characters)');
    return _safe(v.trim());
  }
  if (kind == 'optname') {
    if (isBlank) return null;
    if (v is! String || v.trim().length > 100) throw _bad('$field is too long');
    return _safe(v.trim());
  }
  if (kind == 'lat' || kind == 'lng') {
    final limit = kind == 'lat' ? 90 : 180;
    final x = asNum();
    if (x == null || x < -limit || x > limit) throw _bad('$field must be between -$limit and $limit');
    return x.toDouble();
  }
  if (kind == 'id') {
    final x = asNum();
    if (x == null || x != x.toInt() || x < 1) throw _bad('$field must be a valid id');
    return x.toInt();
  }
  if (kind == 'kmopt') {
    // empty = calculate from the coordinates
    if (isBlank) return null;
    final x = asNum();
    if (x == null || x <= 0 || x >= 100) throw _bad('$field must be a positive distance in km');
    return x.toDouble();
  }
  throw StateError('unknown kind $kind');
}

String _normalizeName(Object? v) {
  final s = (v is String ? v : '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.length < 2) throw _bad('Please enter your name (at least 2 letters)');
  if (s.length > 100) throw _bad('That name is too long');
  return _safe(s);
}

Response _json(Object? body, [int status = 200]) =>
    Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store'});

Future<Map<String, dynamic>> _readJson(Request r) async {
  if ((r.contentLength ?? 0) > 100000) throw _bad('Request too large');
  final text = await r.readAsString();
  if (text.isEmpty) return {};
  try {
    final d = jsonDecode(text);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  throw _bad('Invalid JSON');
}

Handler buildHandler(Db db, Config cfg) {
  final tokens = Tokens(cfg.tokenSecret);
  final hits = <String, List<int>>{}; // naive in-memory rate limit for sign-in endpoints

  void limit(Request r) {
    final ip = (r.context['shelf.io.connection_info'] as dynamic)?.remoteAddress?.address?.toString() ?? 'unknown';
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = (hits[ip] ?? []).where((t) => now - t < 60000).toList()..add(now);
    hits[ip] = list;
    if (list.length > 30) throw HttpError(429, 'Too many attempts. Try again in a minute.');
  }

  Map<String, dynamic> authed(Request r, String role) {
    final h = r.headers['authorization'] ?? '';
    final p = h.startsWith('Bearer ') ? tokens.verify(h.substring(7)) : null;
    if (p == null) throw HttpError(401, 'Please sign in');
    if (p['role'] != role) throw HttpError(403, 'Not allowed');
    return p;
  }

  Future<Response> list(String resource) async {
    final r = _resources[resource]!;
    final rows = await db.all('SELECT * FROM ${r.table} ORDER BY ${r.order}');
    return _json([for (final x in rows) typed(x)]);
  }

  final router = Router();

  // ---------- Sign in (name only): existing name signs in, new name creates the profile ----------
  router.post('/api/auth/enter', (Request r) async {
    limit(r);
    final name = _normalizeName((await _readJson(r))['fullname']);
    var u = await db.get('SELECT user_id, fullname FROM users WHERE fullname = :n', {'n': name});
    var isNew = false;
    if (u == null) {
      await db.run("INSERT INTO users (fullname, date_registered) VALUES (:n, UTC_TIMESTAMP())", {'n': name});
      u = await db.get('SELECT user_id, fullname FROM users WHERE fullname = :n', {'n': name});
      isNew = true;
    }
    final id = int.parse(u!['user_id']!);
    return _json({
      'token': tokens.issue({'sub': id, 'role': 'user'}),
      'user': {'user_id': id, 'fullname': u['fullname'], 'isNew': isNew},
    });
  });

  router.post('/api/auth/director-login', (Request r) async {
    limit(r);
    final b = await _readJson(r);
    final uName = ('${b['username'] ?? ''}').trim();
    final d = await db.get('SELECT * FROM director_of_transport WHERE LOWER(username) = LOWER(:u)', {'u': uName});
    if (d == null || !verifyPassword('${b['password'] ?? ''}', d['password'] ?? '')) throw HttpError(401, 'Wrong username or password');
    return _json({
      'token': tokens.issue({'sub': int.parse(d['directorId']!), 'role': 'director'}, ttl: const Duration(hours: 12)),
      'director': {'username': d['username']},
    });
  });

  router.get('/api/me', (Request r) async {
    final t = authed(r, 'user');
    final u = await db.get('SELECT user_id, fullname FROM users WHERE user_id = :i', {'i': t['sub']});
    if (u == null) throw HttpError(401, 'Please sign in');
    return _json({'user': typed(u)});
  });

  // ---------- Reference data the app downloads, then runs Dijkstra on ----------
  router.get('/api/locations', (Request r) => list('locations'));
  router.get('/api/bus-stops', (Request r) => list('bus-stops'));
  router.get('/api/routes', (Request r) => list('routes'));

  // ---------- Route history ----------
  router.post('/api/history', (Request r) async {
    final t = authed(r, 'user');
    final b = await _readJson(r);
    String field(String k) {
      final v = b[k];
      if (v is! String || v.trim().isEmpty || v.trim().length > 100) throw _bad('$k is required');
      return _safe(v.trim());
    }

    await db.run('INSERT INTO route_history (user_id, source, destination, search_date) VALUES (:u, :s, :d, UTC_TIMESTAMP())',
        {'u': t['sub'], 's': field('source'), 'd': field('destination')});
    return _json({'ok': true});
  });
  router.get('/api/history', (Request r) async {
    final t = authed(r, 'user');
    final rows = await db.all(
        'SELECT history_id, source, destination, search_date FROM route_history WHERE user_id = :u ORDER BY history_id DESC LIMIT 50', {'u': t['sub']});
    return _json([for (final x in rows) typed(x)]);
  });

  /// Fills a blank shuttle-segment distance from the two bus stops' coordinates.
  Future<double> estimate(Map<String, dynamic> v) async {
    final a = await db.get('SELECT latitude, longitude FROM bus_stops WHERE stop_id = :i', {'i': v['start_stop']});
    final b = await db.get('SELECT latitude, longitude FROM bus_stops WHERE stop_id = :i', {'i': v['end_stop']});
    if (a == null || b == null) throw _bad('Could not save: a referenced item does not exist');
    return roadEstimateKm(double.parse(a['latitude']!), double.parse(a['longitude']!), double.parse(b['latitude']!), double.parse(b['longitude']!));
  }

  Future<Map<String, dynamic>> save(String resource, Request r, {int? id}) async {
    final res = _resources[resource]!;
    final body = await _readJson(r);
    final v = <String, dynamic>{for (final e in res.fields.entries) e.key: _clean(e.value, body[e.key], e.key)};
    if (v['start_stop'] != null && v['start_stop'] == v['end_stop']) throw _bad('Start and end stop must differ');
    if (v.containsKey('distance') && v['distance'] == null) v['distance'] = await estimate(v);
    final cols = v.keys.toList();
    try {
      if (id == null) {
        final x = await db.run('INSERT INTO ${res.table} (${cols.join(',')}) VALUES (${cols.map((c) => ':$c').join(',')})', v);
        id = x.insertId;
      } else {
        final x = await db.run('UPDATE ${res.table} SET ${cols.map((c) => '$c = :$c').join(',')} WHERE ${res.pk} = :_id', {...v, '_id': id});
        if (x.changes == 0 && await db.get('SELECT 1 AS x FROM ${res.table} WHERE ${res.pk} = :_id', {'_id': id}) == null) throw HttpError(404, 'Not found');
      }
    } on HttpError {
      rethrow;
    } catch (_) {
      throw _bad('Could not save: the name already exists or a referenced item does not exist');
    }
    return typed((await db.get('SELECT * FROM ${res.table} WHERE ${res.pk} = :_id', {'_id': id}))!);
  }

  for (final name in _resources.keys) {
    final res = _resources[name]!;
    router.post('/api/admin/$name', (Request r) async {
      authed(r, 'director');
      return _json(await save(name, r));
    });
    router.put('/api/admin/$name/<id>', (Request r, String id) async {
      authed(r, 'director');
      return _json(await save(name, r, id: int.tryParse(id) ?? 0));
    });
    router.delete('/api/admin/$name/<id>', (Request r, String id) async {
      authed(r, 'director');
      final x = await db.run('DELETE FROM ${res.table} WHERE ${res.pk} = :i', {'i': int.tryParse(id) ?? 0});
      if (x.changes == 0) throw HttpError(404, 'Not found');
      return _json({'ok': true});
    });
  }

  router.all('/<ignored|.*>', (Request r, String ignored) => _json({'error': 'Not found'}, 404));

  Handler errors(Handler inner) => (Request req) async {
        try {
          return await inner(req);
        } on HttpError catch (e) {
          return _json({'error': e.message}, e.status);
        } catch (e, s) {
          // ignore: avoid_print
          print('Unhandled error: $e\n$s');
          return _json({'error': 'Something went wrong on the server'}, 500);
        }
      };

  return const Pipeline().addMiddleware(errors).addHandler(router.call);
}
