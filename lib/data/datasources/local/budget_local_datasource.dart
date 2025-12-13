import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/budget_model.dart';

class BudgetLocalDatasource {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> cacheBudgets(List<BudgetModel> budgets) async {
    final db = await _db;
    final batch = db.batch();
    
    // Get existing budgets to check for local modifications
    final existingRows = await db.query('budget_allocations');
    final existingBudgets = existingRows.map((row) {
      try {
        return BudgetModel.fromMap(row);
      } catch (_) {
        return null;
      }
    }).whereType<BudgetModel>().toList();
    
    // Create a map of existing budgets for quick lookup
    final existingMap = <String, BudgetModel>{};
    for (final budget in existingBudgets) {
      existingMap[budget.id] = budget;
    }
    
    // Now safe to delete all
    batch.delete('budget_allocations');
    
    // Insert remote budgets, but preserve higher local spent amounts
    for (final b in budgets) {
      final existing = existingMap[b.id];
      final spentAmount = (existing != null && existing.spentAmount > b.spentAmount)
          ? existing.spentAmount
          : b.spentAmount;
      
      batch.insert('budget_allocations', {
        'id': b.id,
        'user_id': b.userId,
        'category': b.category,
        'allocated_amount': b.budgetAmount,
        'spent_amount': spentAmount,
        'month': b.month,
        'year': b.year,
        'created_at': b.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    
    // Re-insert local-only budgets (not yet synced to remote)
    for (final existing in existingBudgets) {
      if (!budgets.any((b) => b.id == existing.id)) {
        batch.insert('budget_allocations', {
          'id': existing.id,
          'user_id': existing.userId,
          'category': existing.category,
          'allocated_amount': existing.budgetAmount,
          'spent_amount': existing.spentAmount,
          'month': existing.month,
          'year': existing.year,
          'created_at': existing.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<BudgetModel>> loadBudgets() async {
    final db = await _db;
    final rows = await db.query('budget_allocations', orderBy: 'created_at DESC');
    return rows.map(BudgetModel.fromMap).toList();
  }
}