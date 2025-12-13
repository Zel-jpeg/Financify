class BudgetModel {
  final String id;
  final String userId;
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final int month;
  final int year;
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.month,
    required this.year,
    required this.createdAt,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      category: map['category'] as String,
      budgetAmount: (map['allocated_amount'] as num).toDouble(),
      spentAmount: (map['spent_amount'] as num).toDouble(),
      month: (map['month'] as num).toInt(),
      year: (map['year'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        if (id.isNotEmpty) 'id': id,
        'user_id': userId,
        'category': category,
        'allocated_amount': budgetAmount,
        'spent_amount': spentAmount,
        'month': month,
        'year': year,
        'created_at': createdAt.toIso8601String(),
      };
}

