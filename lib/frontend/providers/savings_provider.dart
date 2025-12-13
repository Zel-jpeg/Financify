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
    debugPrint('[SavingsProvider] Online: ${_connectivity?.isOffline != true}');
    
    try {
      if (_connectivity?.isOffline != true) {
        try {
          // STEP 1: Sync pending operations first
          debugPrint('[SavingsProvider] Step 1: Syncing pending operations...');
          await syncPending();
          
          // STEP 2: Fetch from Supabase
          debugPrint('[SavingsProvider] Step 2: Fetching from Supabase...');
          final raw = await _service.fetch('savings_goals');
          debugPrint('[SavingsProvider] Supabase returned ${raw.length} raw records');
          
          // Debug: Print first record structure
          if (raw.isNotEmpty) {
            debugPrint('[SavingsProvider] Sample record structure: ${raw.first}');
          }
          
          // STEP 3: Parse to models
          final remoteItems = <SavingsGoalModel>[];
          for (final map in raw) {
            try {
              final goal = SavingsGoalModel.fromMap(map);
              remoteItems.add(goal);
              debugPrint('[SavingsProvider] ✓ Parsed: ${goal.title}');
            } catch (e) {
              debugPrint('[SavingsProvider] ✗ Failed to parse goal: $e');
              debugPrint('[SavingsProvider] Problematic map: $map');
            }
          }
          debugPrint('[SavingsProvider] Successfully parsed ${remoteItems.length} goals');
          
          // STEP 4: Cache with merge logic (preserves local modifications)
          debugPrint('[SavingsProvider] Step 3: Caching goals...');
          await _local.cacheGoals(remoteItems);
          
          // STEP 5: Load from local
          debugPrint('[SavingsProvider] Step 4: Loading from local cache...');
          _items = await _local.loadGoals();
          
          debugPrint('[SavingsProvider] ✓ Final result: Loaded ${_items.length} goals');
          for (final goal in _items) {
            debugPrint('[SavingsProvider]   - ${goal.title}: ${goal.currentAmount}/${goal.targetAmount}');
          }
        } catch (e, stackTrace) {
          debugPrint('[SavingsProvider] ✗ Error loading from Supabase: $e');
          debugPrint('[SavingsProvider] Stack trace: $stackTrace');
          // Fallback to local cache if Supabase fails
          debugPrint('[SavingsProvider] Falling back to local cache...');
          _items = await _local.loadGoals();
          debugPrint('[SavingsProvider] Loaded ${_items.length} goals from local cache');
        }
      } else {
        debugPrint('[SavingsProvider] Offline mode - loading from local only');
        _items = await _local.loadGoals();
        debugPrint('[SavingsProvider] Offline: Loaded ${_items.length} goals from local');
      }
    } catch (e, stackTrace) {
      debugPrint('[SavingsProvider] ✗✗✗ CRITICAL ERROR in load: $e');
      debugPrint('[SavingsProvider] Stack trace: $stackTrace');
      // On error, try to load from local as fallback
      try {
        _items = await _local.loadGoals();
        debugPrint('[SavingsProvider] Emergency fallback: Loaded ${_items.length} goals');
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
    final uid = _service.currentUserId;
    if (uid == null) {
      debugPrint('[SavingsProvider] Cannot add goal - no user ID');
      return;
    }
    
    debugPrint('[SavingsProvider] Adding new goal: $title');
    
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
    
    // STEP 1: Always save locally first
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
    
    // STEP 2: Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.insert('savings_goals', savedGoal.toInsertMap());
        debugPrint('[SavingsProvider] ✓ Goal synced successfully: $id');
      } catch (e) {
        debugPrint('[SavingsProvider] ✗ Failed to sync goal: $e');
        // Queue for sync if Supabase fails
        await _syncQueue.enqueue(
          tableName: 'savings_goals',
          recordId: id,
          operation: 'insert',
          data: savedGoal.toInsertMap(),
        );
      }
    } else {
      // STEP 3: Queue for sync when back online
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
    
    // STEP 1: Update locally first
    _items[idx] = updated;
    await _local.updateGoal(updated);
    notifyListeners();
    
    // STEP 2: Try to sync to Supabase if online
    if (_connectivity?.isOffline != true) {
      try {
        await _service.update('savings_goals', id, {'current_amount': newAmount});
        debugPrint('[SavingsProvider] ✓ Contribution synced: $id');
      } catch (e) {
        debugPrint('[SavingsProvider] ✗ Failed to sync contribution: $e');
        // Queue for sync if Supabase fails
        await _syncQueue.enqueue(
          tableName: 'savings_goals',
          recordId: id,
          operation: 'update',
          data: {'current_amount': newAmount},
        );
      }
    } else {
      // STEP 3: Queue for sync when back online
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
      debugPrint('[SavingsProvider] Skipping sync - offline');
      return;
    }
    
    final pending = await _syncQueue.pending();
    if (pending.isEmpty) {
      debugPrint('[SavingsProvider] No pending items to sync');
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
        // Keep in queue if sync fails and stop to avoid infinite loop
        break;
      }
    }
  }
  
  // BONUS: Method to manually trigger sync
  Future<void> forceSyncNow() async {
    if (_connectivity?.isOffline == true) {
      debugPrint('[SavingsProvider] Cannot force sync - offline');
      return;
    }
    await syncPending();
    await load();
  }
}