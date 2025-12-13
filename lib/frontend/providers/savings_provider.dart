import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/savings_goal_model.dart';
import '../../data/services/supabase_data_service.dart';
import '../../data/datasources/local/savings_local_datasource.dart';
import '../../data/datasources/local/sync_queue_local_datasource.dart';
import 'connectivity_provider.dart';

class SavingsProvider extends ChangeNotifier {
  final SupabaseDataService _service = SupabaseDataService();
  final SavingsLocalDatasource _local = SavingsLocalDatasource();
  final SyncQueueLocalDatasource _syncQueue = SyncQueueLocalDatasource();
  ConnectivityProvider? _connectivity;

  void setConnectivity(ConnectivityProvider connectivity) {
    _connectivity = connectivity;
  }

  bool _loading = false;
  bool get isLoading => _loading;

  List<SavingsGoalModel> _items = [];
  List<SavingsGoalModel> get items => _items;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      if (_connectivity?.isOffline != true) {
        try {
          // Sync pending operations first
          await syncPending();
          // Fetch from Supabase
          final raw = await _service.fetch('savings_goals');
          final remoteItems = raw.map(SavingsGoalModel.fromMap).toList();
          // Load local items to merge
          final localItems = await _local.loadGoals();
          
          // Merge: Use remote data as base, but preserve local current amounts for items that exist locally
          // This ensures offline contributions aren't lost
          final mergedItems = <SavingsGoalModel>[];
          for (final remote in remoteItems) {
            final localMatch = localItems.firstWhere(
              (l) => l.id == remote.id,
              orElse: () => remote,
            );
            // Use local current amount if it's higher (offline contributions) or if remote doesn't exist locally
            mergedItems.add(SavingsGoalModel(
              id: remote.id,
              userId: remote.userId,
              title: remote.title,
              targetAmount: remote.targetAmount,
              currentAmount: localMatch.id == remote.id && localMatch.currentAmount > remote.currentAmount
                  ? localMatch.currentAmount
                  : remote.currentAmount,
              description: remote.description,
              isCompleted: remote.isCompleted,
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
          await _local.cacheGoals(_items);
        } catch (_) {
          // Fallback to local cache if Supabase fails
          _items = await _local.loadGoals();
        }
      } else {
        _items = await _local.loadGoals();
      }
    } catch (e) {
      // On error, try to load from local as fallback
      try {
        _items = await _local.loadGoals();
      } catch (_) {
        _items = [];
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    String? description,
  }) async {
    final uid = _service.currentUserId;
    if (uid == null) return;
    
    final goal = SavingsGoalModel(
      id: '',
      userId: uid,
      title: title,
      targetAmount: targetAmount,
      currentAmount: 0,
      description: description,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    
    // Always save locally first
    final id = await _local.saveGoal(goal);
    final savedGoal = SavingsGoalModel(
      id: id,
      userId: goal.userId,
      title: goal.title,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      description: goal.description,
      isCompleted: goal.isCompleted,
      createdAt: goal.createdAt,
    );
    _items.insert(0, savedGoal);
    notifyListeners();
    
    // Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.insert('savings_goals', savedGoal.toInsertMap());
      } catch (_) {
        // Queue for sync if Supabase fails
        await _syncQueue.enqueue(
          tableName: 'savings_goals',
          recordId: id,
          operation: 'insert',
          data: savedGoal.toInsertMap(),
        );
      }
    } else {
      // Queue for sync when back online
      await _syncQueue.enqueue(
        tableName: 'savings_goals',
        recordId: id,
        operation: 'insert',
        data: savedGoal.toInsertMap(),
      );
    }
  }

  Future<void> addContribution(String id, double amount) async {
    final idx = _items.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    
    final goal = _items[idx];
    final newAmount = goal.currentAmount + amount;
    final updated = SavingsGoalModel(
      id: goal.id,
      userId: goal.userId,
      title: goal.title,
      targetAmount: goal.targetAmount,
      currentAmount: newAmount,
      description: goal.description,
      isCompleted: goal.isCompleted,
      createdAt: goal.createdAt,
    );
    
    _items[idx] = updated;
    await _local.updateGoal(updated);
    notifyListeners();
    
    // Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.update('savings_goals', id, {'current_amount': newAmount});
      } catch (_) {
        // Queue for sync if Supabase fails
        await _syncQueue.enqueue(
          tableName: 'savings_goals',
          recordId: id,
          operation: 'update',
          data: {'current_amount': newAmount},
        );
      }
    } else {
      // Queue for sync when back online
      await _syncQueue.enqueue(
        tableName: 'savings_goals',
        recordId: id,
        operation: 'update',
        data: {'current_amount': newAmount},
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
        if (tableName == 'savings_goals') {
          if (operation == 'insert') {
            await _service.insert('savings_goals', data);
          } else if (operation == 'update') {
            await _service.update('savings_goals', item['record_id'] as String, data);
          }
        }
        await _syncQueue.remove(item['id'] as int);
      } catch (_) {
        // Keep in queue if sync fails
      }
    }
  }
}

