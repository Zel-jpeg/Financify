import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../data/models/budget_model.dart';
import '../../data/services/supabase_data_service.dart';
import '../../data/datasources/local/budget_local_datasource.dart';
import '../../data/datasources/local/sync_queue_local_datasource.dart';
import 'connectivity_provider.dart';

class BudgetProvider extends ChangeNotifier {
  final SupabaseDataService _service = SupabaseDataService();
  final BudgetLocalDatasource _local = BudgetLocalDatasource();
  final SyncQueueLocalDatasource _queue = SyncQueueLocalDatasource();
  final _uuid = const Uuid();
  ConnectivityProvider? _connectivity;

  void setConnectivity(ConnectivityProvider connectivity) {
    _connectivity = connectivity;
  }

  bool _loading = false;
  bool get isLoading => _loading;

  List<BudgetModel> _items = [];
  List<BudgetModel> get items => _items;

  BudgetModel? findByCategory(String category) {
    try {
      return _items.firstWhere(
        (b) => b.category.toLowerCase() == category.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      if (_connectivity?.isOffline != true) {
        try {
          // Sync pending operations first
          await _syncPending();
          // Fetch from Supabase
          final raw = await _service.fetch('budget_allocations');
          final remoteItems = raw.map(BudgetModel.fromMap).toList();
          // Load local items to merge
          final localItems = await _local.loadBudgets();
          
          // Merge: Use remote data as base, but preserve local spent amounts for items that exist locally
          // This ensures offline budget updates aren't lost
          final mergedItems = <BudgetModel>[];
          for (final remote in remoteItems) {
            final localMatch = localItems.firstWhere(
              (l) => l.id == remote.id,
              orElse: () => remote,
            );
            // Use local spent amount if it's higher (offline updates) or if remote doesn't exist locally
            mergedItems.add(BudgetModel(
              id: remote.id,
              userId: remote.userId,
              category: remote.category,
              budgetAmount: remote.budgetAmount,
              spentAmount: localMatch.id == remote.id && localMatch.spentAmount > remote.spentAmount
                  ? localMatch.spentAmount
                  : remote.spentAmount,
              month: remote.month,
              year: remote.year,
              createdAt: remote.createdAt,
            ));
          }
          
          // Add any local-only items (not yet synced)
          for (final local in localItems) {
            if (!mergedItems.any((r) => r.id == local.id)) {
              mergedItems.add(local);
            }
          }
          
          _items = mergedItems;
          await _local.cacheBudgets(_items);
        } catch (_) {
          // Fallback to local cache if Supabase fails
          _items = await _local.loadBudgets();
        }
      } else {
        _items = await _local.loadBudgets();
      }
    } catch (_) {
      _items = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addBudget({
    required String category,
    required double budgetAmount,
  }) async {
    final uid = _service.currentUserId;
    if (uid == null) return;
    final now = DateTime.now();
    final item = BudgetModel(
      id: _uuid.v4(),
      userId: uid,
      category: category,
      budgetAmount: budgetAmount,
      spentAmount: 0,
      month: now.month,
      year: now.year,
      createdAt: DateTime.now(),
    );
    // Always save locally first
    _items = [..._items, item];
    await _local.cacheBudgets(_items);
    notifyListeners();
    
    // Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.insert('budget_allocations', item.toInsertMap());
      } catch (_) {
        // Queue for sync if Supabase fails
        await _queue.enqueue(
          tableName: 'budget_allocations',
          recordId: item.id,
          operation: 'insert',
          data: item.toInsertMap(),
        );
      }
    } else {
      // Queue for sync when back online
      await _queue.enqueue(
        tableName: 'budget_allocations',
        recordId: item.id,
        operation: 'insert',
        data: item.toInsertMap(),
      );
    }
  }

  Future<void> updateSpent(String id, double spent) async {
    final idx = _items.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    final updated = BudgetModel(
      id: _items[idx].id,
      userId: _items[idx].userId,
      category: _items[idx].category,
      budgetAmount: _items[idx].budgetAmount,
      spentAmount: spent,
      month: _items[idx].month,
      year: _items[idx].year,
      createdAt: _items[idx].createdAt,
    );
    _items[idx] = updated;
    await _local.cacheBudgets(_items);
    notifyListeners();
    
    // Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.update('budget_allocations', id, {'spent_amount': spent});
      } catch (_) {
        // Queue for sync if Supabase fails
        await _queue.enqueue(
          tableName: 'budget_allocations',
          recordId: id,
          operation: 'update',
          data: {'spent_amount': spent},
        );
      }
    } else {
      // Queue for sync when back online
      await _queue.enqueue(
        tableName: 'budget_allocations',
        recordId: id,
        operation: 'update',
        data: {'spent_amount': spent},
      );
    }
  }

  Future<void> addSpentForCategory(String category, double amount) async {
    final match = findByCategory(category);
    if (match == null) return;
    final newSpent = match.spentAmount + amount;
    await updateSpent(match.id, newSpent);
  }

  Future<void> applyExpense(String category, double amount) async {
    await addSpentForCategory(category, amount);
  }

  Future<void> _syncPending() async {
    if (_connectivity?.isOffline == true) return;
    final pending = await _queue.pending();
    if (pending.isEmpty) return;
    for (final row in pending) {
      final id = row['id'] as int;
      final op = row['operation'] as String;
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      final recordId = row['record_id'] as String;
      try {
        if (op == 'insert' || op == 'upsert') {
          await _service.upsert('budget_allocations', data);
        } else if (op == 'update') {
          await _service.update('budget_allocations', recordId, data);
        } else if (op == 'delete') {
          await _service.delete('budget_allocations', recordId);
        }
        await _queue.remove(id);
      } catch (_) {
        // stop on first failure to avoid loop
        break;
      }
    }
  }
}

