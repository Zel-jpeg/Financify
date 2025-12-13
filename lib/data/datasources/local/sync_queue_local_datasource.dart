import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';

class SyncQueueLocalDatasource {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation, // insert, update, delete, upsert
    required Map<String, dynamic> data,
  }) async {
    final db = await _db;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> pending() async {
    final db = await _db;
    return db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> remove(int id) async {
    final db = await _db;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTable(String tableName) async {
    final db = await _db;
    await db.delete('sync_queue', where: 'table_name = ?', whereArgs: [tableName]);
  }
}

