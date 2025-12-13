import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../../models/transaction_model.dart';

class TransactionLocalDatasource {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> cacheTransactions(List<TransactionModel> txs) async {
    final db = await _db;
    final batch = db.batch();
    // Get existing transactions to preserve is_synced status
    final existingRows = await db.query('transactions', columns: ['id', 'is_synced']);
    final existingSyncStatus = <String, int>{};
    for (final row in existingRows) {
      existingSyncStatus[row['id'] as String] = row['is_synced'] as int;
    }
    
    // Don't delete all - use upsert to preserve unsynced items
    for (final t in txs) {
      // Preserve existing is_synced status, or mark as synced if new
      final isSynced = existingSyncStatus[t.id] ?? 1;
      batch.insert('transactions', {
        'id': t.id,
        'user_id': t.userId,
        'type': t.type,
        'amount': t.amount,
        'category': t.category,
        'description': t.description,
        'date': t.createdAt.toIso8601String(),
        'is_synced': isSynced, // Preserve existing status
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<String> saveTransaction(TransactionModel tx) async {
    final db = await _db;
    final id = tx.id.isEmpty ? _uuid.v4() : tx.id;
    await db.insert('transactions', {
      'id': id,
      'user_id': tx.userId,
      'type': tx.type,
      'amount': tx.amount,
      'category': tx.category,
      'description': tx.description,
      'date': tx.createdAt.toIso8601String(),
      'is_synced': 0,
      'created_at': tx.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<TransactionModel>> loadTransactions() async {
    final db = await _db;
    final rows = await db.query('transactions', orderBy: 'created_at DESC');
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['created_at'] = map['date'] ?? map['created_at'];
      return TransactionModel.fromMap(map);
    }).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update('transactions', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}

