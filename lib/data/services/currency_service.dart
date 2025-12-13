import 'dart:convert';

import 'package:http/http.dart' as http;

class CurrencyService {
  // Provided API key
  static const _apiKey = 'dbe4b1856bc49a9f023dbb90';
  static const _baseUrl = 'https://v6.exchangerate-api.com/v6';

  Future<Map<String, double>> fetchRates(String baseCurrency) async {
    final uri = Uri.parse('$_baseUrl/$_apiKey/latest/$baseCurrency');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Currency API error: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 'success') {
      throw Exception('Currency API error: ${data['error-type'] ?? 'unknown'}');
    }

    final rates = data['conversion_rates'] as Map<String, dynamic>?;
    if (rates == null || rates.isEmpty) {
      throw Exception('No rates returned');
    }

    return rates.map(
      (key, value) => MapEntry(
        key,
        (value as num).toDouble(),
      ),
    );
  }
}

