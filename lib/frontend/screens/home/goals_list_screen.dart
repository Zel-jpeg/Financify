import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/savings_goal_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/transaction_provider.dart';

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await context.read<SavingsProvider>().load();
      await context.read<TransactionProvider>().load();
      await context.read<BudgetProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<SavingsProvider>();
    final tx = context.read<TransactionProvider>();
    final budgets = context.read<BudgetProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & Savings'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => context.read<SavingsProvider>().load(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: goals.items.length,
          itemBuilder: (context, index) {
            final goal = goals.items[index];
            return _GoalTile(
              goal: goal,
              onContribute: () =>
                  _showContributionSheet(context, goals, tx, budgets, goal.id),
            );
          },
        ),
      ),
    );
  }

  void _showContributionSheet(
    BuildContext context,
    SavingsProvider goals,
    TransactionProvider tx,
    BudgetProvider budgets,
    String goalId,
  ) {
    final amountCtrl = TextEditingController(text: '0');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add Contribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0) return;
                      await goals.addContribution(goalId, amount);
                      await tx.addTransaction(
                        type: 'expense',
                        category: 'Savings Contribution',
                        amount: amount,
                        description: 'Goal contribution',
                      );
                      await budgets.addSpentForCategory(
                          'Savings Contribution', amount);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6CE1AF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final SavingsGoalModel goal;
  final VoidCallback onContribute;

  const _GoalTile({
    required this.goal,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAmount == 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0, 1);
    final created = DateFormat('MMM dd, yyyy').format(goal.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE8F8EF).withOpacity(0.15)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                created,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goal.description ?? '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            backgroundColor: Colors.green.withOpacity(0.15),
            color: const Color(0xFF0B8F6B),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₱${goal.currentAmount.toStringAsFixed(0)} / ₱${goal.targetAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: onContribute,
                child: const Text('Contribute'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

