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
    
    debugPrint('[SavingsProvider] ========== LOADING SAVINGS GOALS ==========');
    
    try {
      // Get current user ID first
      final userId = await _service.getCurrentUserId();
      debugPrint('[SavingsProvider] Loading for user: $userId');
      
      if (userId == null) {
        debugPrint('[SavingsProvider] No user ID - clearing data');
        _items = [];
        _loading = false;
        notifyListeners();
        return;
      }
      
      if (_connectivity?.isOffline != true) {
        try {
          // STEP 1: Sync pending operations first
          debugPrint('[SavingsProvider] Syncing pending operations...');
          await syncPending();
          
          // STEP 2: Fetch from Supabase
          debugPrint('[SavingsProvider] Fetching from Supabase...');
          final raw = await _service.fetch('savings_goals');
          debugPrint('[SavingsProvider] Supabase returned ${raw.length} raw records');
          
          // STEP 3: Parse to models
          final remoteItems = <SavingsGoalModel>[];
          for (final map in raw) {
            try {
              final goal = SavingsGoalModel.fromMap(map);
              remoteItems.add(goal);
              debugPrint('[SavingsProvider] ✓ Parsed: ${goal.title}');
            } catch (e) {
              debugPrint('[SavingsProvider] ✗ Failed to parse goal: $e');
            }
          }
          debugPrint('[SavingsProvider] Successfully parsed ${remoteItems.length} goals');
          
          // STEP 4: Cache with merge logic
          await _local.cacheGoals(remoteItems);
          
          // STEP 5: Load from local
          _items = await _local.loadGoals();
          
          // STEP 6: Filter by current user ID
          _items = _items.where((g) => g.userId == userId).toList();
          
          debugPrint('[SavingsProvider] ✓ Final result: ${_items.length} goals for user $userId');
        } catch (e, stackTrace) {
          debugPrint('[SavingsProvider] ✗ Error loading from Supabase: $e');
          debugPrint('[SavingsProvider] Stack trace: $stackTrace');
          // Fallback to local cache
          _items = await _local.loadGoals();
          _items = _items.where((g) => g.userId == userId).toList();
          debugPrint('[SavingsProvider] Loaded ${_items.length} goals from local cache');
        }
      } else {
        debugPrint('[SavingsProvider] Offline mode - loading from local only');
        _items = await _local.loadGoals();
        _items = _items.where((g) => g.userId == userId).toList();
        debugPrint('[SavingsProvider] Offline: Loaded ${_items.length} goals');
      }
    } catch (e, stackTrace) {
      debugPrint('[SavingsProvider] ✗✗✗ CRITICAL ERROR in load: $e');
      debugPrint('[SavingsProvider] Stack trace: $stackTrace');
      try {
        _items = await _local.loadGoals();
        final userId = await _service.getCurrentUserId();
        if (userId != null) {
          _items = _items.where((g) => g.userId == userId).toList();
        }
        debugPrint('[SavingsProvider] Emergency fallback: ${_items.length} goals');
      } catch (e2) {
        debugPrint('[SavingsProvider] Even fallback failed: $e2');
        _items = [];
      }
    } finally {
      _loading = false;
      debugPrint('[SavingsProvider] ========== LOADING COMPLETE ==========');
      notifyListeners();
    }
  }

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    String? description,
  }) async {
    final uid = await _service.getCurrentUserId();
    if (uid == null) {
      debugPrint('[SavingsProvider] Cannot add goal - no user ID');
      return;
    }
    
    debugPrint('[SavingsProvider] Adding new goal: $title for user: $uid');
    
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
        debugPrint('[SavingsProvider] ✓ Goal synced successfully: $id');
      } catch (e) {
        debugPrint('[SavingsProvider] ✗ Failed to sync goal: $e');
        await _syncQueue.enqueue(
          tableName: 'savings_goals',
          recordId: id,
          operation: 'insert',
          data: savedGoal.toInsertMap(),
        );
      }
    } else {
      await _syncQueue.enqueue(
        tableName: 'savings_goals',
        recordId: id,
        operation: 'insert',
        data: savedGoal.toInsertMap(),
      );
      debugPrint('[SavingsProvider] Goal queued for sync: $id');
    }
  }

  Future<void> addContribution(String id, double amount) async {
    final idx = _items.indexWhere((g) => g.id == id);
    if (idx == -1) {
      debugPrint('[SavingsProvider] Cannot add contribution - goal not found: $id');
      return;
    }
    
    debugPrint('[SavingsProvider] Adding contribution: $amount to goal $id');
    
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
    
    if (_connectivity?.isOffline != true) {
      try {
        await _service.update('savings_goals', id, {'current_amount': newAmount});
        debugPrint('[SavingsProvider] ✓ Contribution synced: $id');
      } catch (e) {
        debugPrint('[SavingsProvider] ✗ Failed to sync contribution: $e');
        await _syncQueue.enqueue(
          tableName: 'savings_goals',
          recordId: id,
          operation: 'update',
          data: {'current_amount': newAmount},
        );
      }
    } else {
      await _syncQueue.enqueue(
        tableName: 'savings_goals',
        recordId: id,
        operation: 'update',
        data: {'current_amount': newAmount},
      );
      debugPrint('[SavingsProvider] Contribution queued for sync: $id');
    }
  }

  Future<void> syncPending() async {
    if (_connectivity?.isOffline == true) {
      return;
    }
    
    final pending = await _syncQueue.pending();
    if (pending.isEmpty) {
      return;
    }
    
    debugPrint('[SavingsProvider] Syncing ${pending.length} pending items');
    
    for (final item in pending) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final recordId = item['record_id'] as String;
        final data = Map<String, dynamic>.from(
          jsonDecode(item['data'] as String),
        );
        
        if (tableName != 'savings_goals') continue;
        
        if (operation == 'insert') {
          await _service.insert('savings_goals', data);
          debugPrint('[SavingsProvider] ✓ Synced goal: $recordId');
        } else if (operation == 'update') {
          await _service.update('savings_goals', recordId, data);
          debugPrint('[SavingsProvider] ✓ Updated goal: $recordId');
        } else if (operation == 'delete') {
          await _service.delete('savings_goals', recordId);
          debugPrint('[SavingsProvider] ✓ Deleted goal: $recordId');
        }
        
        await _syncQueue.remove(item['id'] as int);
      } catch (e) {
        debugPrint('[SavingsProvider] ✗ Failed to sync item: $e');
        break;
      }
    }
  }
  
  Future<void> forceSyncNow() async {
    if (_connectivity?.isOffline == true) {
      debugPrint('[SavingsProvider] Cannot force sync - offline');
      return;
    }
    await syncPending();
    await load();
  }
}