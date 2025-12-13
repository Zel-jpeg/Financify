import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/savings_goal_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../auth/signin_screen.dart';
import 'goals_list_screen.dart';
import 'recent_transactions_screen.dart';
import '../../widgets/animated_entry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<String> expenseCategories = [
    'Food',
    'Transportation',
    'Allowance',
    'Other'
  ];
  static const List<String> incomeCategories = [
    'Allowance',
    'Scholarship',
    'Part-time',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final metadata = user?.userMetadata;
    final displayName = (metadata?['full_name'] as String?) ??
        (metadata?['name'] as String?) ??
        (metadata?['display_name'] as String?) ??
        (metadata?['given_name'] as String?) ??
        'User';
    final firstName = displayName.trim().isEmpty
        ? 'User'
        : displayName.trim().split(' ').first;
    final photoUrl = (metadata?['avatar_url'] as String?) ??
        (metadata?['picture'] as String?) ??
        (metadata?['avatar'] as String?);
    final tx = Provider.of<TransactionProvider>(context);
    final budgets = Provider.of<BudgetProvider>(context);
    final goals = Provider.of<SavingsProvider>(context);

    final balance = tx.totalIncome - tx.totalExpense;
    final recent = tx.items.take(3).toList();
    final headlineGoal =
        goals.items.isNotEmpty ? goals.items.first : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([tx.load(), budgets.load(), goals.load()]);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeaderCard(
              userName: firstName,
              photoUrl: photoUrl,
              balance: balance,
              onIncomeTap: () => _showTransactionSheet(context, tx, 'income'),
              onExpenseTap: () => _showTransactionSheet(context, tx, 'expense'),
              onBudgetTap: () => _showBudgetSheet(context, budgets),
              onGoalTap: () => _showGoalSheet(context, goals),
              onLogout: () => _handleSignOut(context, authProvider),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  _SectionTitle(
                    title: 'Goals/Savings',
                    actionText: goals.items.isEmpty ? '' : 'See all',
                    onAction: goals.items.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GoalsListScreen(),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  _GoalCard(
                    goal: headlineGoal,
                    onTap: headlineGoal == null
                        ? null
                        : () => _showContributionSheet(
                              context,
                              goals,
                              tx,
                              headlineGoal.id,
                            ),
            ),
            const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Recent Activities',
                    actionText: recent.isEmpty ? '' : 'See all',
                    onAction: recent.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RecentTransactionsScreen(),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  if (recent.isEmpty)
                    _EmptyState(message: 'No transactions yet')
                  else
                    ...recent.asMap().entries.map(
                      (entry) => AnimatedEntry(
                        index: entry.key,
                        child: _ActivityTile(
                          transaction: entry.value,
                          onTap: () => _showTransactionDetails(context, entry.value),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Budget'),
                  const SizedBox(height: 12),
                  if (budgets.items.isEmpty)
                    _EmptyState(message: 'No budgets yet')
                  else
                    Column(
                      children: budgets.items
                          .asMap()
                          .entries
                          .map(
                            (entry) => AnimatedEntry(
                              index: entry.key,
                              child: _BudgetCard(
                                category: entry.value.category,
                                spent: entry.value.spentAmount,
                                total: entry.value.budgetAmount,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await authProvider.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  void _showTransactionSheet(
    BuildContext context,
    TransactionProvider tx,
    String type,
  ) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenseOptions = ([
      ...expenseCategories,
      ...budgetProvider.items.map((b) => b.category),
    ].toSet().toList()
      ..sort());
    final initialCategory =
        type == 'income' ? incomeCategories.first : expenseOptions.first;

    String selectedCategory = initialCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return FractionallySizedBox(
            heightFactor: 0.7,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
        padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                    const SizedBox(height: 24),
                    // Income/Expense Amount Label
            Text(
                      type == 'income' ? 'Income Amount' : 'Expense Amount',
              style: const TextStyle(
                        fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
                    const SizedBox(height: 8),
                // Amount Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Amount',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
              ),
            ),
                    const SizedBox(height: 20),
                    // Category Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (ctx) => Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Select ${type == 'income' ? 'Income' : 'Expense'} Category',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...(type == 'income'
                      ? incomeCategories
                      : expenseOptions)
                                      .map((cat) => ListTile(
                                            title: Text(cat),
                                            onTap: () {
                                              setState(() {
                                                selectedCategory = cat;
                                              });
                                              Navigator.pop(ctx);
                                            },
                                          ))
                  .toList(),
                                ],
                              ),
                            ),
                          );
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              selectedCategory,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_drop_down, size: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Description Label
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
            ),
                    const SizedBox(height: 8),
                    // Description Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
              controller: descCtrl,
                        maxLines: 4,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
              ),
            ),
                    const SizedBox(height: 24),
                    // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0) return;
                  await tx.addTransaction(
                    type: type,
                            category: selectedCategory,
                    amount: amount,
                    description:
                        descCtrl.text.isEmpty ? null : descCtrl.text,
                  );
                  if (type == 'expense') {
                            await budgetProvider.addSpentForCategory(selectedCategory, amount);
                  }
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
                          'Save',
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
          );
        },
      ),
    );
  }

  void _showBudgetSheet(BuildContext context, BudgetProvider budgets) {
    final amountCtrl = TextEditingController(text: '0');
    String category = expenseCategories.first;
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
              'Add Budget',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Category',
              value: category,
              items: expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => category = val ?? category,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                labelText: 'Budget Amount',
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
                  await budgets.addBudget(
                    category: category,
                    budgetAmount: amount,
                  );
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
                  'Save',
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

  void _showGoalSheet(BuildContext context, SavingsProvider goals) {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '0');
    final descCtrl = TextEditingController();
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
              'Create Goal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
                  decoration: InputDecoration(
                labelText: 'Goal name',
                filled: true,
                    fillColor: Theme.of(context).cardColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                labelText: 'Target amount',
                filled: true,
                    fillColor: Theme.of(context).cardColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
                  decoration: InputDecoration(
                labelText: 'Description',
                filled: true,
                    fillColor: Theme.of(context).cardColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final target = double.tryParse(targetCtrl.text) ?? 0;
                  if (target <= 0) return;
                  await goals.addGoal(
                    title: titleCtrl.text.isEmpty ? 'New Goal' : titleCtrl.text,
                    targetAmount: target,
                    description:
                        descCtrl.text.isEmpty ? null : descCtrl.text,
                  );
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
                  'Save',
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

  void _showContributionSheet(
    BuildContext context,
    SavingsProvider goals,
    TransactionProvider tx,
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
                  // Record as an expense to reflect on balance and budgets
                  final tx = context.read<TransactionProvider>();
                  final budgets = context.read<BudgetProvider>();
                  await tx.addTransaction(
                    type: 'expense',
                    category: 'Savings Contribution',
                    amount: amount,
                    description: 'Goal contribution',
                  );
                  await budgets.addSpentForCategory('Savings Contribution', amount);
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

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel t,
  ) {
    final title = _activityTitle(t);
    final date = DateFormat('MMMM dd, yyyy • h:mm a').format(t.createdAt);
    final amount = t.amount;
    final isIncome = t.type == 'income';
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
      ),
        child: Container(
          padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                date,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
            Text(
                      isIncome
                          ? '+₱${amount.toStringAsFixed(2)}'
                          : '-₱${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                fontWeight: FontWeight.bold,
                        color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
                  ],
                ),
              ),
            if (t.description != null && t.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
              Text(
                'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE8F8EF).withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t.description!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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
                    'Close',
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
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final double balance;
  final VoidCallback onIncomeTap;
  final VoidCallback onExpenseTap;
  final VoidCallback onBudgetTap;
  final VoidCallback onGoalTap;
  final VoidCallback onLogout;

  const _HeaderCard({
    required this.userName,
    this.photoUrl,
    required this.balance,
    required this.onIncomeTap,
    required this.onExpenseTap,
    required this.onBudgetTap,
    required this.onGoalTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? LinearGradient(
                colors: [
                  const Color(0xFFE8F8EF).withOpacity(0.15),
                  const Color(0xFFE8F8EF).withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFE7FFF4), Color(0xFFC9F0E1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl!) : null,
                      child: photoUrl == null
                          ? Icon(Icons.person, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $userName',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                        Text(
                          date,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                /*Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                    child: IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                      ),
                  )*/
            ],
          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Container(
            width: double.infinity,
              padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B8F6B), Color(0xFF08563F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                  const SizedBox(height: 6),
                Text(
                  '₱${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                      fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeaderButton(
                      icon: Icons.work_outline,
                      label: 'Income',
                      onTap: onIncomeTap,
                    ),
                    _HeaderButton(
                      icon: Icons.dashboard_customize,
                      label: 'Allocate',
                      onTap: onBudgetTap,
                    ),
                    _HeaderButton(
                      icon: Icons.receipt_long,
                      label: 'Expenses',
                      onTap: onExpenseTap,
                    ),
                    _HeaderButton(
                      icon: Icons.savings_outlined,
                      label: 'Save',
                      onTap: onGoalTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
            ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.title,
    this.actionText = '',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        if (actionText.isNotEmpty)
          TextButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoalModel? goal;
  final VoidCallback? onTap;

  const _GoalCard({required this.goal, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return _EmptyState(message: 'No goals yet');
    }
    final progress = goal!.targetAmount == 0
        ? 0.0
        : (goal!.currentAmount / goal!.targetAmount).clamp(0, 1);

    final theme = Theme.of(context);
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFFE8F8EF).withOpacity(0.15)
            : const Color(0xFFE8F8EF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.track_changes, color: Color(0xFF0B8F6B)),
              ),
              const SizedBox(width: 12),
              Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal!.title,
                      style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
            ),
          ),
                    const SizedBox(height: 4),
                    Text(
                      goal!.description ?? 'Keep pushing towards your savings goal!',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            backgroundColor: Colors.green.withOpacity(0.15),
            color: const Color(0xFF0B8F6B),
          ),
          const SizedBox(height: 8),
          Text(
            '₱${goal!.currentAmount.toStringAsFixed(0)} / ₱${goal!.targetAmount.toStringAsFixed(0)}',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _ActivityTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final date =
        DateFormat('MMMM dd, yyyy • h:mm a').format(transaction.createdAt);
    final title = _activityTitle(transaction);
    final amountText = isIncome
        ? '+₱${transaction.amount.toStringAsFixed(2)}'
        : '-₱${transaction.amount.toStringAsFixed(2)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE8F8EF).withOpacity(0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isIncome
                  ? AppColors.success.withOpacity(0.15)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFDE7E7).withOpacity(0.2)
                      : const Color(0xFFFDE7E7),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? AppColors.success : const Color(0xFFD9534F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.success : const Color(0xFFD9534F),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.receipt_long, size: 18, color: Colors.grey),
              ],
            )
          ],
        ),
      ),
    );
  }
}

String _activityTitle(TransactionModel t) {
  return t.type == 'income'
      ? 'Received ${t.category}'
      : 'Paid ${t.category}';
}

class _BudgetCard extends StatelessWidget {
  final String category;
  final double spent;
  final double total;

  const _BudgetCard({
    required this.category,
    required this.spent,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (spent / total).clamp(0, 1);

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFFE8F8EF).withOpacity(0.15)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                category,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Budget: ₱${total.toStringAsFixed(0)}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Expense: ₱${spent.toStringAsFixed(2)}',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFFE8F8EF).withOpacity(0.15)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: onChanged,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}