import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/animated_entry.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tx = Provider.of<TransactionProvider>(context);
    final budgets = Provider.of<BudgetProvider>(context);

    final totalIncome = tx.totalIncome;
    final totalExpense = tx.totalExpense;
    final balance = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedEntry(
                  child: _StatCard(
                    title: 'Income',
                    value: '₱${totalIncome.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedEntry(
                  index: 1,
                  child: _StatCard(
                    title: 'Expenses',
                    value: '₱${totalExpense.toStringAsFixed(2)}',
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedEntry(
            index: 2,
            child: _StatCard(
              title: 'Balance',
              value: '₱${balance.toStringAsFixed(2)}',
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Allocation Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          _AllocationDonut(budgets: budgets),
          const SizedBox(height: 24),
          const Text(
            'Categories',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (budgets.items.isEmpty)
            const Text('No budgets yet', style: TextStyle(color: Colors.grey))
          else
            ...budgets.items.asMap().entries.map(
              (entry) => AnimatedEntry(
                index: entry.key,
                child: _BudgetTile(
                  title: entry.value.category,
                  spent: entry.value.spentAmount,
                  total: entry.value.budgetAmount,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationDonut extends StatefulWidget {
  final BudgetProvider budgets;
  const _AllocationDonut({required this.budgets});

  @override
  State<_AllocationDonut> createState() => _AllocationDonutState();
}

class _AllocationDonutState extends State<_AllocationDonut>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    );
    _rotationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset and restart rotation when navigating back
    _rotationController.reset();
    _rotationController.forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.budgets.items.isEmpty) {
      return _PlaceholderCircle();
    }

    final totalSpent =
        widget.budgets.items.fold<double>(0, (sum, b) => sum + b.spentAmount);
    if (totalSpent == 0) {
      return _PlaceholderCircle();
    }

    final sections = widget.budgets.items.map((b) {
      final value = (b.spentAmount / totalSpent) * 100;
      return PieChartSectionData(
        value: value,
        color: Colors.primaries[
            widget.budgets.items.indexOf(b) % Colors.primaries.length],
        radius: 62,
        title: '${value.toStringAsFixed(0)}%',
        titleStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 12,
        ),
        badgeWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            b.category,
            style: TextStyle(
              color: Colors.primaries[
                  widget.budgets.items.indexOf(b) % Colors.primaries.length],
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        badgePositionPercentageOffset: 1.25,
      );
    }).toList();

    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 2 * 3.14159, // Full rotation
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 60,
                sections: sections,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceholderCircle extends StatelessWidget {
  @override
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No budget data yet',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final String title;
  final double spent;
  final double total;

  const _BudgetTile({
    required this.title,
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
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Budget: ₱${total.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Expense: ₱${spent.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

