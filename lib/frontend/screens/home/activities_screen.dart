import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_provider.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Activities')),
      body: Consumer<TransactionProvider>(
        builder: (context, tx, _) {
          final items = tx.items;
          if (items.isEmpty) {
            return const Center(child: Text('No activities yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final t = items[index];
              return _ActivityTile(
                transaction: t,
                onTap: () => _showDetails(context, t),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, TransactionModel t) {
    final isIncome = t.type == 'income';
    final date = DateFormat('MMMM dd, yyyy • h:mm a').format(t.createdAt);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
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
            Text(
              _activityTitle(t),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isIncome
                  ? '+₱${t.amount.toStringAsFixed(2)}'
                  : '-₱${t.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text('Category: ${t.category}'),
            Text('Date: $date'),
            if (t.description != null && t.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(t.description!),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

String _activityTitle(TransactionModel t) {
  final isIncome = t.type == 'income';
  if (isIncome) {
    return 'Received +₱${t.amount.toStringAsFixed(2)} from ${t.category}';
  }
  return 'Paid -₱${t.amount.toStringAsFixed(2)} for ${t.category}';
}

class _ActivityTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final date =
        DateFormat('MMM dd, yyyy • h:mm a').format(transaction.createdAt);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isIncome ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activityTitle(transaction),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

