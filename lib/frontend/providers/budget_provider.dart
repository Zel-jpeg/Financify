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
    
    debugPrint('[BudgetProvider] ========== LOADING BUDGETS ==========');
    
    try {
      // Get current user ID first
      final userId = await _service.getCurrentUserId();
      debugPrint('[BudgetProvider] Loading for user: $userId');
      
      if (userId == null) {
        debugPrint('[BudgetProvider] No user ID - clearing data');
        _items = [];
        _loading = false;
        notifyListeners();
        return;
      }
      
      if (_connectivity?.isOffline != true) {
        try {
          // Sync pending operations first
          await _syncPending();
          
          // Fetch from Supabase
          final raw = await _service.fetch('budget_allocations');
          final remoteItems = raw.map(BudgetModel.fromMap).toList();
          debugPrint('[BudgetProvider] Fetched ${remoteItems.length} remote budgets');
          
          // Load local items to merge
          final localItems = await _local.loadBudgets();
          
          // Merge: preserve local spent amounts for items that exist locally
          final mergedItems = <BudgetModel>[];
          for (final remote in remoteItems) {
            final localMatch = localItems.firstWhere(
              (l) => l.id == remote.id,
              orElse: () => remote,
            );
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
          
          // Filter by current user ID
          _items = mergedItems.where((b) => b.userId == userId).toList();
          debugPrint('[BudgetProvider] ✓ Filtered to ${_items.length} budgets for user $userId');
          
          await _local.cacheBudgets(_items);
        } catch (e) {
          debugPrint('[BudgetProvider] ✗ Error loading from Supabase: $e');
          // Fallback to local cache if Supabase fails
          _items = await _local.loadBudgets();
          _items = _items.where((b) => b.userId == userId).toList();
          debugPrint('[BudgetProvider] Loaded ${_items.length} budgets from local cache');
        }
      } else {
        _items = await _local.loadBudgets();
        _items = _items.where((b) => b.userId == userId).toList();
        debugPrint('[BudgetProvider] Offline: Loaded ${_items.length} budgets');
      }
    } catch (e) {
      debugPrint('[BudgetProvider] ✗✗✗ Error in load: $e');
      _items = [];
    }
    
    _loading = false;
    debugPrint('[BudgetProvider] ========== LOADING COMPLETE ==========');
    notifyListeners();
  }

  Future<void> addBudget({
    required String category,
    required double budgetAmount,
  }) async {
    final uid = await _service.getCurrentUserId();
    if (uid == null) {
      debugPrint('[BudgetProvider] Cannot add budget - no user ID');
      return;
    }
    
    debugPrint('[BudgetProvider] Adding budget for user: $uid');
    
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
        debugPrint('[BudgetProvider] ✓ Budget synced successfully');
      } catch (e) {
        debugPrint('[BudgetProvider] ✗ Failed to sync budget: $e');
        await _queue.enqueue(
          tableName: 'budget_allocations',
          recordId: item.id,
          operation: 'insert',
          data: item.toInsertMap(),
        );
      }
    } else {
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
        await _queue.enqueue(
          tableName: 'budget_allocations',
          recordId: id,
          operation: 'update',
          data: {'spent_amount': spent},
        );
      }
    } else {
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
        break;
      }
    }
  }
}