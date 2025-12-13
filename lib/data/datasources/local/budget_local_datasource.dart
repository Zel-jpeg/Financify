import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/budget_model.dart';

class BudgetLocalDatasource {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> cacheBudgets(List<BudgetModel> budgets) async {
    final db = await _db;
    final batch = db.batch();
    batch.delete('budget_allocations');
    for (final b in budgets) {
      batch.insert('budget_allocations', {
        'id': b.id,
        'user_id': b.userId,
        'category': b.category,
        'allocated_amount': b.budgetAmount,
        'spent_amount': b.spentAmount,
        'month': b.month,
        'year': b.year,
        'created_at': b.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<BudgetModel>> loadBudgets() async {
    final db = await _db;
    final rows = await db.query('budget_allocations', orderBy: 'created_at DESC');
    return rows.map(BudgetModel.fromMap).toList();
  }
}

