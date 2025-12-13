import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyProvider({CurrencyService? service})
      : _service = service ?? CurrencyService();

  final CurrencyService _service;
  static const _prefsKeyRates = 'currency_rates';
  static const _prefsKeyBase = 'currency_base';
  static const _prefsKeyTimestamp = 'currency_timestamp';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _baseCurrency = 'USD';
  String get baseCurrency => _baseCurrency;

  String _targetCurrency = 'PHP';
  String get targetCurrency => _targetCurrency;

  double _amount = 1;
  double get amount => _amount;

  double _convertedValue = 0;
  double get convertedValue => _convertedValue;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  Map<String, double> _rates = {};
  Map<String, double> get rates => _rates;

  final List<String> _preferredCurrencies = [
    'EUR',
    'GBP',
    'JPY',
    'PHP',
    'AUD',
    'CAD',
  ];
  List<String> get preferredCurrencies => _preferredCurrencies;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadCachedRates();
    await loadRates();
  }

  Future<void> loadRates({String? base}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final selectedBase = base ?? _baseCurrency;
    try {
      final fetchedRates = await _service.fetchRates(selectedBase);
      _rates = fetchedRates;
      _baseCurrency = selectedBase;
      _lastUpdated = DateTime.now();
      await _persistRates();
      _recalculate();
    } catch (e) {
      _errorMessage = 'Unable to refresh rates. Showing saved data.';
      if (_rates.isEmpty) {
        await _loadCachedRates();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setAmount(double value) {
    _amount = value;
    _recalculate();
    notifyListeners();
  }

  void setTargetCurrency(String currency) {
    _targetCurrency = currency;
    _recalculate();
    notifyListeners();
  }

  void setBaseCurrency(String currency) {
    if (currency == _baseCurrency) return;
    loadRates(base: currency);
  }

  Future<void> _loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRates = prefs.getString(_prefsKeyRates);
    if (rawRates != null) {
      final decoded = jsonDecode(rawRates) as Map<String, dynamic>;
      _rates = decoded.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    }
    _baseCurrency = prefs.getString(_prefsKeyBase) ?? _baseCurrency;
    final timestamp = prefs.getString(_prefsKeyTimestamp);
    if (timestamp != null) {
      _lastUpdated = DateTime.tryParse(timestamp);
    }
    _recalculate();
  }

  Future<void> _persistRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyRates, jsonEncode(_rates));
    await prefs.setString(_prefsKeyBase, _baseCurrency);
    if (_lastUpdated != null) {
      await prefs.setString(
        _prefsKeyTimestamp,
        _lastUpdated!.toIso8601String(),
      );
    }
  }

  void _recalculate() {
    if (_rates.isEmpty) {
      _convertedValue = 0;
      return;
    }
    final rate = _rates[_targetCurrency];
    if (rate == null) {
      _convertedValue = 0;
      return;
    }
    _convertedValue = _amount * rate;
  }
}

