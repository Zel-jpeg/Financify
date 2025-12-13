import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../../models/savings_goal_model.dart';

class SavingsLocalDatasource {
  final _uuid = const Uuid();
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> cacheGoals(List<SavingsGoalModel> goals) async {
    final db = await _db;
    final batch = db.batch();
    batch.delete('savings_goals');
    for (final g in goals) {
      batch.insert('savings_goals', {
        'id': g.id,
        'user_id': g.userId,
        'name': g.title,
        'description': g.description,
        'target_amount': g.targetAmount,
        'current_amount': g.currentAmount,
        'is_completed': g.isCompleted ? 1 : 0,
        'created_at': g.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<String> saveGoal(SavingsGoalModel goal) async {
    final db = await _db;
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;
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
    return rows.map((row) {
      try {
        return SavingsGoalModel.fromMap(row);
      } catch (e) {
        // Handle any parsing errors gracefully
        return null;
      }
    }).whereType<SavingsGoalModel>().toList();
  }
}

