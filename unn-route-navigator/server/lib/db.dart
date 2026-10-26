import 'dart:async';
import 'package:mysql_client/mysql_client.dart';
import 'config.dart';
import 'schema.dart';

/// One MySQL connection, used one query at a time, reconnecting if it drops.
/// Column values come back as strings from the driver; see typed() in api.dart.
class Db {
  final Config cfg;
  MySQLConnection? _conn;
  Future<void> _tail = Future<void>.value();
  Db(this.cfg);

  Future<MySQLConnection> _connection() async {
    final existing = _conn;
    if (existing != null && existing.connected) return existing;
    final conn = await MySQLConnection.createConnection(
      host: cfg.dbHost,
      port: cfg.dbPort,
      userName: cfg.dbUser,
      password: cfg.dbPassword,
      secure: cfg.dbSecure,
    );
    await conn.connect();
    await conn.execute('CREATE DATABASE IF NOT EXISTS `${cfg.dbName}` CHARACTER SET utf8mb4');
    await conn.execute('USE `${cfg.dbName}`');
    _conn = conn;
    return conn;
  }

  Future<T> _locked<T>(Future<T> Function(MySQLConnection c) job) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final c = await _connection();
        try {
          done.complete(await job(c));
        } catch (e, s) {
          if (!c.connected) _conn = null;
          done.completeError(e, s);
        }
      } catch (e, s) {
        _conn = null;
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  Future<List<Map<String, String?>>> all(String sql, [Map<String, dynamic>? params]) =>
      _locked((c) async {
        final res = await c.execute(sql, params);
        return [for (final r in res.rows) r.assoc()];
      });

  Future<Map<String, String?>?> get(String sql, [Map<String, dynamic>? params]) async {
    final rows = await all(sql, params);
    return rows.isEmpty ? null : rows.first;
  }

  /// INSERT / UPDATE / DELETE. Returns the new id (inserts) and the rows changed.
  Future<({int insertId, int changes})> run(String sql, [Map<String, dynamic>? params]) =>
      _locked((c) async {
        final res = await c.execute(sql, params);
        return (insertId: res.lastInsertID.toInt(), changes: res.affectedRows.toInt());
      });

  /// Creates tables (and upgrades the old email/password users table to name-only).
  Future<void> ensureSchema() async {
    for (final s in schemaStatements) {
      await run(s);
    }
    final old = await all("SHOW COLUMNS FROM users LIKE 'email'");
    if (old.isNotEmpty) {
      try {
        await run('ALTER TABLE users DROP COLUMN email, DROP COLUMN password');
        await run('ALTER TABLE users ADD UNIQUE (fullname)');
      } catch (e) {
        // ignore: avoid_print
        print('[schema] Could not fully upgrade the users table (duplicate names?): $e');
      }
    }
  }
}
