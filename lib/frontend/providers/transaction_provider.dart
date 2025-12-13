import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/supabase_data_service.dart';
import '../../data/datasources/local/transaction_local_datasource.dart';
import '../../data/datasources/local/sync_queue_local_datasource.dart';
import 'connectivity_provider.dart';

class TransactionProvider extends ChangeNotifier {
  final SupabaseDataService _service = SupabaseDataService();
  final TransactionLocalDatasource _local = TransactionLocalDatasource();
  final SyncQueueLocalDatasource _syncQueue = SyncQueueLocalDatasource();
  ConnectivityProvider? _connectivity;

  void setConnectivity(ConnectivityProvider connectivity) {
    _connectivity = connectivity;
  }

  bool _loading = false;
  bool get isLoading => _loading;

  List<TransactionModel> _items = [];
  List<TransactionModel> get items => _items;

  double get totalIncome => _items
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _items
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      if (_connectivity?.isOffline != true) {
        try {
          // Sync pending operations first
          await syncPending();
          // Reload local items after sync to get updated is_synced status
          final localItems = await _local.loadTransactions();
          // Fetch from Supabase
          final raw = await _service.fetch('transactions');
          final remoteItems = raw.map(TransactionModel.fromMap).toList();
          
          // Merge: Combine remote and local transactions, avoiding duplicates
          final mergedItems = <TransactionModel>[];
          final seenIds = <String>{};
          
          // Add all remote items first (these are the source of truth)
          for (final remote in remoteItems) {
            mergedItems.add(remote);
            seenIds.add(remote.id);
          }
          
          // Add local items that aren't in remote (unsynced items)
          // These are transactions that were created offline but not yet synced
          for (final local in localItems) {
            if (!seenIds.contains(local.id)) {
              mergedItems.add(local);
            }
          }
          
          // Sort by date (newest first)
          mergedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          _items = mergedItems;
          // Update local cache with merged data, preserving is_synced status
          await _local.cacheTransactions(_items);
        } catch (_) {
          // Fallback to local if Supabase fails
          _items = await _local.loadTransactions();
        }
      } else {
        _items = await _local.loadTransactions();
      }
    } catch (_) {
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction({
    required String type,
    required String category,
    required double amount,
    String? description,
  }) async {
    final uid = _service.currentUserId;
    if (uid == null) return;
    
    final tx = TransactionModel(
      id: '',
      userId: uid,
      type: type,
      category: category,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
    );
    
    // Always save locally first
    final id = await _local.saveTransaction(tx);
    final savedTx = TransactionModel(
      id: id,
      userId: tx.userId,
      type: tx.type,
      category: tx.category,
      amount: tx.amount,
      description: tx.description,
      createdAt: tx.createdAt,
    );
    _items.insert(0, savedTx);
    notifyListeners();
    
    // Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.insert('transactions', savedTx.toInsertMap());
        await _local.markSynced(id);
      } catch (_) {
        // Queue for sync if Supabase fails
        await _syncQueue.enqueue(
          tableName: 'transactions',
          recordId: id,
          operation: 'insert',
          data: savedTx.toInsertMap(),
        );
      }
    } else {
      // Queue for sync when back online
      await _syncQueue.enqueue(
        tableName: 'transactions',
        recordId: id,
        operation: 'insert',
        data: savedTx.toInsertMap(),
      );
    }
  }

  Future<void> syncPending() async {
    if (_connectivity?.isOffline == true) return;
    final pending = await _syncQueue.pending();
    for (final item in pending) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final data = Map<String, dynamic>.from(
          jsonDecode(item['data'] as String),
        );
        if (tableName == 'transactions') {
          if (operation == 'insert') {
            await _service.insert('transactions', data);
            await _local.markSynced(data['id'] as String);
          }
        }
        await _syncQueue.remove(item['id'] as int);
      } catch (_) {
        // Keep in queue if sync fails
        break; // Stop on first failure to avoid infinite loop
      }
    }
    // Don't call load() here to avoid infinite recursion
    // The caller will reload if needed
  }
}

