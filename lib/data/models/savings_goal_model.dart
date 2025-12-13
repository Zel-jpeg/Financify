class SavingsGoalModel {
  final String id;
  final String userId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? description;
  final bool isCompleted;
  final DateTime createdAt;

  SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.description,
    required this.isCompleted,
    required this.createdAt,
  });

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map) {
    // Handle is_completed which can be bool (Supabase) or int (SQLite)
    bool parseCompleted(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return false;
    }

    // Handle created_at which might be timestamptz (Supabase) or string (SQLite)
    DateTime parseCreatedAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return SavingsGoalModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      description: map['description'] as String?,
      isCompleted: parseCompleted(map['is_completed']),
      createdAt: parseCreatedAt(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        if (id.isNotEmpty) 'id': id,
        'user_id': userId,
        'name': title,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'description': description,
        'is_completed': isCompleted,
        'created_at': createdAt.toIso8601String(),
      };
}