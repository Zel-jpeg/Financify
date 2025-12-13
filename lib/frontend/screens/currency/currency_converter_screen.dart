import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/currency_provider.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final TextEditingController _amountController =
      TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CurrencyProvider>();
      provider.initialize();
      _amountController.text = provider.amount.toString();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline =
        context.watch<ConnectivityProvider>().isOffline;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Currency Converter'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: Consumer<CurrencyProvider>(
        builder: (context, provider, _) {
          final symbol = _symbolFor(provider.targetCurrency);
          return RefreshIndicator(
            onRefresh: provider.loadRates,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'You are offline. Showing the last saved rates.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                _CurrencyCard(
                  title: 'From',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CurrencyDropdown(
                        value: provider.baseCurrency,
                        onChanged: provider.setBaseCurrency,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          final amount = double.tryParse(value) ?? 0;
                          provider.setAmount(amount);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CurrencyCard(
                  title: 'To',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CurrencyDropdown(
                        value: provider.targetCurrency,
                        onChanged: provider.setTargetCurrency,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        provider.isLoading
                            ? 'Converting...'
                          : '$symbol${provider.convertedValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.lastUpdated != null)
                        Text(
                          'Updated ${provider.lastUpdated}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Other Currencies',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () =>
                          _showAllRates(context, provider.rates),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (provider.rates.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  ...provider.preferredCurrencies.map(
                    (code) => _OtherCurrencyTile(
                      code: code,
                      rate: provider.rates[code],
                      amount: provider.amount,
                      base: provider.baseCurrency,
                    ),
                  ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAllRates(
    BuildContext context,
    Map<String, double> rates,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: rates.entries
            .map(
              (entry) => ListTile(
                title: Text(entry.key),
                trailing: Text(entry.value.toStringAsFixed(4)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _CurrencyCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CurrencyDropdown({
    required this.value,
    required this.onChanged,
  });

  static const _currencies = [
    'USD',
    'PHP',
    'EUR',
    'GBP',
    'JPY',
    'AUD',
    'CAD',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: _currencies
            .map(
              (currency) => DropdownMenuItem<String>(
                value: currency,
                child: Text(currency),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

class _OtherCurrencyTile extends StatelessWidget {
  final String code;
  final double? rate;
  final double amount;
  final String base;

  const _OtherCurrencyTile({
    required this.code,
    required this.rate,
    required this.amount,
    required this.base,
  });

  @override
  Widget build(BuildContext context) {
    final converted =
        rate == null ? '—' : (amount * rate!).toStringAsFixed(2);
    final symbol = _symbolFor(code);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(code,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('1 $base = ${rate?.toStringAsFixed(4) ?? '—'} $code'),
            ],
          ),
          Text(
            rate == null ? converted : '$symbol$converted',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

String _symbolFor(String code) {
  const map = {
    'USD': '\$',
    'PHP': '₱',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'SGD': 'S\$',
  };
  return map[code] ?? '';
}

