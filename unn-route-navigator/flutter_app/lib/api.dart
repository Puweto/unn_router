import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Bumped whenever the user signs in or out so the root widget rebuilds.
final ValueNotifier<int> sessionVersion = ValueNotifier<int>(0);

class Session {
  static String? token;
  static String? role; // 'user' | 'director'
  static Map<String, dynamic>? user;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    role = p.getString('role');
  }

  static Future<void> start(String t, String r,
      {Map<String, dynamic>? userInfo}) async {
    token = t;
    role = r;
    user = userInfo;
    final p = await SharedPreferences.getInstance();
    await p.setString('token', t);
    await p.setString('role', r);
    sessionVersion.value++;
  }

  static Future<void> end() async {
    token = null;
    role = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('role');
    sessionVersion.value++;
  }
}

class Api {
  static Future<dynamic> _send(String method, String path,
      {Object? body}) async {
    final uri = Uri.parse('$kApiBaseUrl/api$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
    };
    final encoded = body == null ? null : jsonEncode(body);
    http.Response res;
    try {
      const timeout = Duration(seconds: 15);
      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(timeout);
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(timeout);
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(timeout);
        default:
          res = await http.get(uri, headers: headers).timeout(timeout);
      }
    } catch (e) {
      throw ApiException('Cannot reach $kApiBaseUrl\n$e');
    }
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode == 401 && Session.token != null) await Session.end();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Request failed (${res.statusCode})';
      throw ApiException(msg, res.statusCode);
    }
    return data;
  }

  // ----- authentication: name only. A known name signs in, a new name creates the profile -----
  static Future<void> enter(String fullname) async {
    final r = await _send('POST', '/auth/enter', body: {'fullname': fullname});
    await Session.start(r['token'] as String, 'user',
        userInfo: Map<String, dynamic>.from(r['user'] as Map));
  }

  static Future<void> directorLogin(String username, String password) async {
    final r = await _send('POST', '/auth/director-login',
        body: {'username': username, 'password': password});
    await Session.start(r['token'] as String, 'director');
  }

  static Future<Map<String, dynamic>> me() async {
    final r = await _send('GET', '/me');
    return Map<String, dynamic>.from(r['user'] as Map);
  }

  // ----- reference data -----
  static Future<List<Map<String, dynamic>>> _list(String path) async {
    final r = await _send('GET', path);
    return [for (final x in (r as List)) Map<String, dynamic>.from(x as Map)];
  }

  static Future<Reference> reference() async {
    final results = await Future.wait(
        [_list('/locations'), _list('/bus-stops'), _list('/routes')]);
    return Reference(
      [for (final j in results[0]) Place.location(j)],
      [for (final j in results[1]) Place.stop(j)],
      results[2],
    );
  }

  // ----- user features -----
  static Future<void> saveHistory(String source, String destination) =>
      _send('POST', '/history',
          body: {'source': source, 'destination': destination});

  static Future<List<HistoryItem>> history() async {
    final rows = await _list('/history');
    return [
      for (final h in rows)
        HistoryItem(h['source'] as String, h['destination'] as String,
            h['search_date'] as String)
    ];
  }

  // ----- Director of Transport -----
  static Future<List<Map<String, dynamic>>> adminList(String path) =>
      _list(path);
  static Future<void> adminSave(String path, Map<String, dynamic> body,
          {int? id}) =>
      _send(id == null ? 'POST' : 'PUT', id == null ? path : '$path/$id',
          body: body);
  static Future<void> adminDelete(String path, int id) =>
      _send('DELETE', '$path/$id');
}
