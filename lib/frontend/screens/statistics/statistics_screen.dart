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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budget Allocation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),

              // Legend under the title
              Row(
                children: [
                  _LegendItem(
                    color: Colors.blue.withOpacity(0.3),
                    label: 'Budget (Washed Color)',
                  ),
                  const SizedBox(width: 12),
                  _LegendItem(
                    color: Colors.blue,
                    label: 'Spent (Solid Color)',
                  ),
                ],
              ),
            ],
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  
  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
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
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Rotation animation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    );
    
    // Scale animation (pop in effect)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    _startAnimations();
  }

  void _startAnimations() {
    _scaleController.forward();
    _rotationController.forward();
  }

  @override
  void didUpdateWidget(_AllocationDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart animations when data changes
    if (widget.budgets.items.length != oldWidget.budgets.items.length) {
      _restartAnimations();
    }
  }

  void _restartAnimations() {
    _scaleController.reset();
    _rotationController.reset();
    _startAnimations();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.budgets.items.isEmpty) {
      return _PlaceholderCircle();
    }

    final totalBudget = widget.budgets.items.fold<double>(
      0, 
      (sum, b) => sum + b.budgetAmount,
    );
    
    if (totalBudget == 0) {
      return _PlaceholderCircle();
    }

    // Create TWO separate pie charts:
    // 1. Outer layer = Full budget (light color, larger radius)
    // 2. Inner layer = Spent amount (solid color, smaller radius, fills up)
    
    final budgetSections = <PieChartSectionData>[];
    final spentSections = <PieChartSectionData>[];

    for (var i = 0; i < widget.budgets.items.length; i++) {
      final budget = widget.budgets.items[i];
      final percentage = (budget.budgetAmount / totalBudget) * 100;
      final color = Colors.primaries[i % Colors.primaries.length];
      
      // Outer layer - Full budget allocation (light, washed color)
      budgetSections.add(
        PieChartSectionData(
          value: percentage,
          color: color.withOpacity(0.25),
          radius: 80,
          title: '',
          borderSide: BorderSide(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
      );

      // Inner layer - Spent amount (fills up based on spent/budget ratio)
      // Calculate how much of THIS slice should be filled
      final spentRatio = budget.budgetAmount > 0 
          ? (budget.spentAmount / budget.budgetAmount).clamp(0.0, 1.0)
          : 0.0;
      
      // The "filled" portion: percentage * spentRatio
      final filledValue = percentage * spentRatio;
      // The "empty" portion: percentage * (1 - spentRatio)
      final emptyValue = percentage * (1 - spentRatio);
      
      // Add the FILLED part (solid color)
      if (filledValue > 0) {
        spentSections.add(
          PieChartSectionData(
            value: filledValue,
            color: color,
            radius: 60,
            title: spentRatio > 0.15 ? '${(spentRatio * 100).toStringAsFixed(0)}%' : '',
            titleStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 11,
            ),
            badgeWidget: spentRatio > 0.5 ? _buildBadge(context, budget, color) : null,
            badgePositionPercentageOffset: 1.5,
          ),
        );
      }
      
      // Add the EMPTY part (transparent, to maintain spacing)
      if (emptyValue > 0) {
        spentSections.add(
          PieChartSectionData(
            value: emptyValue,
            color: Colors.transparent,
            radius: 60,
            title: '',
          ),
        );
      }
      
      // Add badge for budgets with low spending (shown on outer ring)
      if (spentRatio <= 0.5) {
        final midIndex = budgetSections.length - 1;
        budgetSections[midIndex] = PieChartSectionData(
          value: percentage,
          color: color.withOpacity(0.25),
          radius: 80,
          title: '',
          borderSide: BorderSide(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
          badgeWidget: _buildBadge(context, budget, color),
          badgePositionPercentageOffset: 1.35,
        );
      }
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: SizedBox(
              height: 280,
              child: Stack(
                children: [
                  // Outer ring - Full budget (light/washed color)
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sections: budgetSections,
                      sectionsSpace: 3,
                      startDegreeOffset: 0,
                    ),
                  ),
                  // Inner ring - Spent amount (solid color, fills progressively)
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sections: spentSections,
                      sectionsSpace: 3,
                      startDegreeOffset: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(BuildContext context, budget, Color color) {
    // Calculate percentage of total budget
    final totalBudget = widget.budgets.items.fold<double>(
      0, 
      (sum, b) => sum + b.budgetAmount,
    );
    final budgetPercentage = totalBudget > 0 
        ? (budget.budgetAmount / totalBudget * 100).toStringAsFixed(0)
        : '0';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                budget.category,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$budgetPercentage%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '₱${budget.spentAmount.toStringAsFixed(0)}/₱${budget.budgetAmount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCircle extends StatelessWidget {
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
        'No budget allocations yet',
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
    final remaining = total - spent;

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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: remaining >= 0 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: remaining >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₱${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₱${spent.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₱${remaining.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: remaining >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: progress > 0.9 
                  ? Colors.red 
                  : progress > 0.7 
                      ? Colors.orange 
                      : Colors.teal,
            ),
          ),
        ],
      ),
    );
  }
}