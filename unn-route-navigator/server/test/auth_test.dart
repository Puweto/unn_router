import 'package:test/test.dart';
import 'package:unn_route_server/auth.dart';
import 'package:unn_route_server/geo.dart';

void main() {
  test('pbkdf2 matches the RFC 7914 test vector for HMAC-SHA-256', () {
    // PBKDF2-HMAC-SHA256, P="passwd", S="salt", c=1, dkLen=64 (RFC 7914 section 11)
    final out = pbkdf2('passwd', 'salt'.codeUnits, 1, 64);
    final hex = out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex.startsWith('55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'), isTrue);
  });

  test('password hashing verifies only the right password', () {
    final h = hashPassword('director123');
    expect(verifyPassword('director123', h), isTrue);
    expect(verifyPassword('wrong', h), isFalse);
    expect(verifyPassword('x', 'garbage'), isFalse);
  });

  test('tokens verify, expire and reject tampering', () {
    final t = Tokens('secret');
    final token = t.issue({'sub': 5, 'role': 'user'});
    expect(t.verify(token)!['sub'], 5);
    expect(Tokens('other').verify(token), isNull);
    expect(t.verify('${token}x'), isNull);
    expect(t.verify(t.issue({'sub': 1}, ttl: const Duration(seconds: -5))), isNull);
    expect(t.verify(null), isNull);
  });

  test('road estimate: 0.01 degree of latitude is about 1.39 km of road', () {
    expect(roadEstimateKm(6.85, 7.4, 6.86, 7.4), closeTo(1.39, 0.02));
  });
}
