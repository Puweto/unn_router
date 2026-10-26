import 'dart:io';
import 'dart:math';

/// Settings come from environment variables so no secrets live in the code.
class Config {
  final int port;
  final String dbHost, dbUser, dbPassword, dbName;
  final int dbPort;
  final bool dbSecure;
  final String tokenSecret;
  final bool tokenSecretWasGenerated;
  final String directorUsername;
  final String? directorPassword;
  final bool seedDatabase;

  Config._(this.port, this.dbHost, this.dbPort, this.dbUser, this.dbPassword, this.dbName, this.dbSecure,
      this.tokenSecret, this.tokenSecretWasGenerated, this.directorUsername, this.directorPassword, this.seedDatabase);

  factory Config.fromEnv([Map<String, String>? env]) {
    final Map<String, String> merged = Map<String, String>.from(Platform.environment);
    final envFile = File('.env');
    if (envFile.existsSync()) {
      for (final line in envFile.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final idx = trimmed.indexOf('=');
        if (idx > 0) {
          final k = trimmed.substring(0, idx).trim();
          var v = trimmed.substring(idx + 1).trim();
          if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
            v = v.substring(1, v.length - 1);
          }
          merged[k] = v;
        }
      }
    }
    final e = env ?? merged;
    var secret = e['TOKEN_SECRET'];
    final generated = secret == null || secret.isEmpty;
    if (generated) {
      final r = Random.secure();
      secret = List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    }
    return Config._(
      int.tryParse(e['PORT'] ?? '') ?? 3000,
      e['DB_HOST'] ?? '127.0.0.1',
      int.tryParse(e['DB_PORT'] ?? '') ?? 3306,
      e['DB_USER'] ?? 'root',
      e['DB_PASSWORD'] ?? '',
      e['DB_NAME'] ?? 'unn_route_navigator',
      (e['DB_SECURE'] ?? 'true').toLowerCase() == 'true',
      secret,
      generated,
      e['DIRECTOR_USERNAME'] ?? 'director',
      e['DIRECTOR_PASSWORD'],
      (e['SEED_DATABASE'] ?? 'false').toLowerCase() == 'true',
    );
  }
}
