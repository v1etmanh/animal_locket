import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CacheDatabase {
  CacheDatabase._(this._database);
  final Database _database;
  static Future<CacheDatabase> open() async {
    final directory = await getApplicationSupportDirectory();
    final database = await openDatabase(
      '${directory.path}/animal_locket_cache.db',
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cache_entries (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        );
      },
    );
    return CacheDatabase._(database);
  }

  Future<void> write(String key, Object payload) async =>
      _database.insert('cache_entries', {
        'cache_key': key,
        'payload': jsonEncode(payload),
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<Object?> read(String key) async {
    final rows = await _database.query(
      'cache_entries',
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload']! as String);
  }

  Future<void> clear() async => _database.delete('cache_entries');
  Future<void> close() => _database.close();
}

final cacheDatabaseProvider = FutureProvider<CacheDatabase>((ref) async {
  final database = await CacheDatabase.open();
  ref.onDispose(database.close);
  return database;
});
