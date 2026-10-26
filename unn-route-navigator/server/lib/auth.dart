import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

const _iterations = 60000;

List<int> pbkdf2(String password, List<int> salt, int iterations, int length) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final blocks = (length / 32).ceil();
  final out = <int>[];
  for (var i = 1; i <= blocks; i++) {
    var u = hmac.convert([...salt, (i >> 24) & 255, (i >> 16) & 255, (i >> 8) & 255, i & 255]).bytes;
    final t = List<int>.from(u);
    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    out.addAll(t);
  }
  return out.sublist(0, length);
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
List<int> _unhex(String s) => [for (var i = 0; i + 1 < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Used for the Director of Transport password only (regular users sign in with a name).
String hashPassword(String password) {
  final r = Random.secure();
  final salt = List<int>.generate(16, (_) => r.nextInt(256));
  return 'pbkdf2\$$_iterations\$${_hex(salt)}\$${_hex(pbkdf2(password, salt, _iterations, 32))}';
}

bool verifyPassword(String password, String stored) {
  final p = stored.split('\$');
  if (p.length != 4 || p[0] != 'pbkdf2') return false;
  try {
    final iterations = int.parse(p[1]);
    return _constantTimeEquals(pbkdf2(password, _unhex(p[2]), iterations, 32), _unhex(p[3]));
  } catch (_) {
    return false;
  }
}

/// Signed, expiring session tokens (HMAC-SHA256).
class Tokens {
  final List<int> _key;
  Tokens(String secret) : _key = utf8.encode(secret);

  String _sign(String body) => base64Url.encode(Hmac(sha256, _key).convert(utf8.encode(body)).bytes).replaceAll('=', '');

  String issue(Map<String, dynamic> payload, {Duration ttl = const Duration(days: 30)}) {
    final data = {...payload, 'exp': DateTime.now().add(ttl).millisecondsSinceEpoch ~/ 1000};
    final body = base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    return '$body.${_sign(body)}';
  }

  Map<String, dynamic>? verify(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 2) return null;
    if (!_constantTimeEquals(utf8.encode(parts[1]), utf8.encode(_sign(parts[0])))) return null;
    try {
      final data = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0])))) as Map<String, dynamic>;
      final exp = data['exp'];
      if (exp is! int || exp * 1000 < DateTime.now().millisecondsSinceEpoch) return null;
      return data;
    } catch (_) {
      return null;
    }
  }
}
