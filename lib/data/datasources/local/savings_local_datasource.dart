import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../local/database_helper.dart';
import '../../models/savings_goal_model.dart';

class SavingsLocalDatasource {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> cacheGoals(List<SavingsGoalModel> goals) async {
    final db = await _db;
    final batch = db.batch();
    
    debugPrint('[SavingsLocalDatasource] Caching ${goals.length} goals from remote');
    
    // Get existing goals to check for local modifications
    final existingRows = await db.query('savings_goals');
    debugPrint('[SavingsLocalDatasource] Found ${existingRows.length} existing goals in local DB');
    
    final existingGoals = <SavingsGoalModel>[];
    for (final row in existingRows) {
      try {
        final goal = SavingsGoalModel.fromMap(row);
        existingGoals.add(goal);
      } catch (e) {
        debugPrint('[SavingsLocalDatasource] Error parsing existing goal: $e');
        debugPrint('[SavingsLocalDatasource] Problematic row: $row');
      }
    }
    
    // Create a map of existing goals for quick lookup
    final existingMap = <String, SavingsGoalModel>{};
    for (final goal in existingGoals) {
      existingMap[goal.id] = goal;
    }
    
    // Now safe to delete all
    batch.delete('savings_goals');
    
    // Insert remote goals, but preserve higher local current amounts
    for (final g in goals) {
      final existing = existingMap[g.id];
      final currentAmount = (existing != null && existing.currentAmount > g.currentAmount)
          ? existing.currentAmount
          : g.currentAmount;
      
      debugPrint('[SavingsLocalDatasource] Inserting goal: ${g.title} (${g.id})');
      debugPrint('[SavingsLocalDatasource] - target: ${g.targetAmount}, current: $currentAmount, completed: ${g.isCompleted}');
      
      batch.insert('savings_goals', {
        'id': g.id,
        'user_id': g.userId,
        'name': g.title,
        'description': g.description,
        'target_amount': g.targetAmount,
        'current_amount': currentAmount,
        'is_completed': g.isCompleted ? 1 : 0, // Convert bool to int for SQLite
        'created_at': g.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    
    // Re-insert local-only goals (not yet synced to remote)
    int localOnlyCount = 0;
    for (final existing in existingGoals) {
      if (!goals.any((g) => g.id == existing.id)) {
        localOnlyCount++;
        debugPrint('[SavingsLocalDatasource] Re-inserting local-only goal: ${existing.title}');
        batch.insert('savings_goals', {
          'id': existing.id,
          'user_id': existing.userId,
          'name': existing.title,
          'description': existing.description,
          'target_amount': existing.targetAmount,
          'current_amount': existing.currentAmount,
          'is_completed': existing.isCompleted ? 1 : 0,
          'created_at': existing.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
    
    debugPrint('[SavingsLocalDatasource] Re-inserted $localOnlyCount local-only goals');
    await batch.commit(noResult: true);
    debugPrint('[SavingsLocalDatasource] Cache complete - total goals should be: ${goals.length + localOnlyCount}');
  }

  Future<String> saveGoal(SavingsGoalModel goal) async {
    final db = await _db;
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;
    debugPrint('[SavingsLocalDatasource] Saving new goal: ${goal.title} ($id)');
    
    await db.insert('savings_goals', {
      'id': id,
      'user_id': goal.userId,
      'name': goal.title,
      'description': goal.description,
      'target_amount': goal.targetAmount,
      'current_amount': goal.currentAmount,
      'is_completed': goal.isCompleted ? 1 : 0,
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    return id;
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    final db = await _db;
    debugPrint('[SavingsLocalDatasource] Updating goal: ${goal.title} (${goal.id})');
    
    await db.update('savings_goals', {
      'name': goal.title,
      'description': goal.description,
      'target_amount': goal.targetAmount,
      'current_amount': goal.currentAmount,
      'is_completed': goal.isCompleted ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<List<SavingsGoalModel>> loadGoals() async {
    final db = await _db;
    final rows = await db.query('savings_goals', orderBy: 'created_at DESC');
    debugPrint('[SavingsLocalDatasource] Loading ${rows.length} goals from local DB');
    
    final goals = <SavingsGoalModel>[];
    for (final row in rows) {
      try {
        final goal = SavingsGoalModel.fromMap(row);
        goals.add(goal);
        debugPrint('[SavingsLocalDatasource] ✓ Loaded: ${goal.title} - ${goal.currentAmount}/${goal.targetAmount}');
      } catch (e) {
        debugPrint('[SavingsLocalDatasource] ✗ Error parsing goal: $e');
        debugPrint('[SavingsLocalDatasource] Problematic row: $row');
      }
    }
    
    debugPrint('[SavingsLocalDatasource] Successfully loaded ${goals.length} goals');
    return goals;
  }
}