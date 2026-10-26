import 'dart:io';
import 'package:shelf/shelf_io.dart' as io;
import 'package:unn_route_server/api.dart';
import 'package:unn_route_server/config.dart';
import 'package:unn_route_server/db.dart';
import 'package:unn_route_server/seed.dart';

Future<void> main() async {
  final cfg = Config.fromEnv();
  if (cfg.tokenSecretWasGenerated) {
    stderr.writeln('[auth] TOKEN_SECRET not set: users will have to sign in again whenever the server restarts.');
  }
  final db = Db(cfg);
  try {
    await db.ensureSchema();
    await seed(db, cfg);
  } catch (e) {
    stderr.writeln('Could not set up MySQL at ${cfg.dbHost}:${cfg.dbPort} as "${cfg.dbUser}".\n'
        'Check that MySQL is running and that DB_USER / DB_PASSWORD are right.\nDetails: $e');
    exit(1);
  }
  final server = await io.serve(buildHandler(db, cfg), InternetAddress.anyIPv4, cfg.port);
  stdout.writeln('UNN Route Navigator API running on http://localhost:${server.port}');
}
