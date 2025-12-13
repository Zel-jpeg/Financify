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
    
    debugPrint('[TransactionProvider] ========== LOADING TRANSACTIONS ==========');
    
    try {
      // Get current user ID first
      final userId = await _service.getCurrentUserId();
      debugPrint('[TransactionProvider] Loading for user: $userId');
      
      if (userId == null) {
        debugPrint('[TransactionProvider] No user ID - clearing data');
        _items = [];
        _loading = false;
        notifyListeners();
        return;
      }
      
      if (_connectivity?.isOffline != true) {
        try {
          // STEP 1: Sync pending operations first
          debugPrint('[TransactionProvider] Syncing pending operations...');
          await syncPending();
          
          // STEP 2: Fetch from Supabase (returns empty for guest mode)
          debugPrint('[TransactionProvider] Fetching from Supabase...');
          final raw = await _service.fetch('transactions');
          final remoteItems = raw.map(TransactionModel.fromMap).toList();
          debugPrint('[TransactionProvider] Fetched ${remoteItems.length} remote transactions');
          
          // STEP 3: Cache remote items (preserves unsynced items)
          await _local.cacheTransactions(remoteItems);
          
          // STEP 4: Load from local (includes both synced and unsynced)
          _items = await _local.loadTransactions();
          debugPrint('[TransactionProvider] Loaded ${_items.length} total transactions from local');
          
          // STEP 5: Filter by current user ID
          _items = _items.where((t) => t.userId == userId).toList();
          debugPrint('[TransactionProvider] ✓ Filtered to ${_items.length} transactions for user $userId');
        } catch (e) {
          debugPrint('[TransactionProvider] ✗ Error loading from Supabase: $e');
          // Fallback to local if Supabase fails
          _items = await _local.loadTransactions();
          _items = _items.where((t) => t.userId == userId).toList();
          debugPrint('[TransactionProvider] Loaded ${_items.length} transactions from local cache');
        }
      } else {
        // Offline mode: load from local and filter by user
        debugPrint('[TransactionProvider] Offline mode - loading from local only');
        _items = await _local.loadTransactions();
        _items = _items.where((t) => t.userId == userId).toList();
        debugPrint('[TransactionProvider] Loaded ${_items.length} transactions for user $userId');
      }
    } catch (e) {
      debugPrint('[TransactionProvider] ✗✗✗ Error in load: $e');
      _items = [];
    } finally {
      _loading = false;
      debugPrint('[TransactionProvider] ========== LOADING COMPLETE ==========');
      notifyListeners();
    }
  }

  Future<void> addTransaction({
    required String type,
    required String category,
    required double amount,
    String? description,
  }) async {
    final uid = await _service.getCurrentUserId();
    if (uid == null) {
      debugPrint('[TransactionProvider] Cannot add transaction - no user ID');
      return;
    }
    
    debugPrint('[TransactionProvider] Adding $type transaction for user: $uid');
    
    final tx = TransactionModel(
      id: '',
      userId: uid,
      type: type,
      category: category,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
    );
    
    // STEP 1: Always save locally first (marked as unsynced)
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
    
    // STEP 2: Update UI immediately
    _items.insert(0, savedTx);
    notifyListeners();
    
    // STEP 3: Try to sync to Supabase if online (skipped for guest mode)
    if (_connectivity?.isOffline != true) {
      try {
        await _service.insert('transactions', savedTx.toInsertMap());
        await _local.markSynced(id);
        debugPrint('[TransactionProvider] ✓ Transaction synced successfully: $id');
      } catch (e) {
        debugPrint('[TransactionProvider] ✗ Failed to sync transaction: $e');
        await _syncQueue.enqueue(
          tableName: 'transactions',
          recordId: id,
          operation: 'insert',
          data: savedTx.toInsertMap(),
        );
      }
    } else {
      await _syncQueue.enqueue(
        tableName: 'transactions',
        recordId: id,
        operation: 'insert',
        data: savedTx.toInsertMap(),
      );
      debugPrint('[TransactionProvider] Transaction queued for sync: $id');
    }
  }

  Future<void> syncPending() async {
    if (_connectivity?.isOffline == true) {
      debugPrint('[TransactionProvider] Skipping sync - offline');
      return;
    }
    
    final pending = await _syncQueue.pending();
    if (pending.isEmpty) {
      return;
    }
    
    debugPrint('[TransactionProvider] Syncing ${pending.length} pending items');
    
    for (final item in pending) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final recordId = item['record_id'] as String;
        final data = Map<String, dynamic>.from(
          jsonDecode(item['data'] as String),
        );
        
        if (tableName == 'transactions') {
          if (operation == 'insert') {
            await _service.insert('transactions', data);
            await _local.markSynced(recordId);
            debugPrint('[TransactionProvider] ✓ Synced transaction: $recordId');
          }
        }
        
        await _syncQueue.remove(item['id'] as int);
      } catch (e) {
        debugPrint('[TransactionProvider] ✗ Failed to sync item: $e');
        break;
      }
    }
  }
  
  Future<void> forceSyncNow() async {
    if (_connectivity?.isOffline == true) {
      debugPrint('[TransactionProvider] Cannot force sync - offline');
      return;
    }
    await syncPending();
    await load();
  }
}