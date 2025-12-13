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
    
    // CRITICAL FIX: Get all unsynced transactions BEFORE deleting
    final unsyncedRows = await db.query(
      'transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    
    // Convert unsynced rows to TransactionModel
    final unsyncedTransactions = unsyncedRows.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['created_at'] = map['date'] ?? map['created_at'];
      return TransactionModel.fromMap(map);
    }).toList();
    
    // Now it's safe to delete - we have unsynced items saved
    batch.delete('transactions');
    
    // Insert all remote transactions (these are synced)
    for (final t in txs) {
      batch.insert('transactions', {
        'id': t.id,
        'user_id': t.userId,
        'type': t.type,
        'amount': t.amount,
        'category': t.category,
        'description': t.description,
        'date': t.createdAt.toIso8601String(),
        'is_synced': 1, // Remote items are always synced
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    
    // Re-insert unsynced transactions that weren't in the remote data
    for (final unsynced in unsyncedTransactions) {
      // Only add if not already in remote data
      if (!txs.any((t) => t.id == unsynced.id)) {
        batch.insert('transactions', {
          'id': unsynced.id,
          'user_id': unsynced.userId,
          'type': unsynced.type,
          'amount': unsynced.amount,
          'category': unsynced.category,
          'description': unsynced.description,
          'date': unsynced.createdAt.toIso8601String(),
          'is_synced': 0, // Keep as unsynced
          'created_at': unsynced.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
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
  
  // BONUS: Add this method to help with debugging
  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['created_at'] = map['date'] ?? map['created_at'];
      return TransactionModel.fromMap(map);
    }).toList();
  }
}