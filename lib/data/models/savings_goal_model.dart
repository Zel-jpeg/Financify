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
    return SavingsGoalModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      description: map['description'] as String?,
      isCompleted: map['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
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

