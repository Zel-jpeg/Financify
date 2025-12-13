class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'income' or 'expense'
  final String category;
  final double amount;
  final String? description;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: map['type'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String? ?? map['date'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        if (id.isNotEmpty) 'id': id,
        'user_id': userId,
        'type': type,
        'category': category,
        'amount': amount,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}

  