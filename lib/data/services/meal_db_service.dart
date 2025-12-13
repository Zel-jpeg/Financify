import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/recipe_model.dart';

class MealDbService {
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1';
  final http.Client _client;

  MealDbService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('MealDB error: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<RecipeModel> getRandomMeal() async {
    final data = await _get('/random.php');
    final meals = data['meals'] as List<dynamic>?;
    if (meals == null || meals.isEmpty) {
      throw Exception('No meals found');
    }
    return RecipeModel.fromJson(meals.first as Map<String, dynamic>);
  }

  Future<RecipeModel> getMealById(String id) async {
    final data = await _get('/lookup.php?i=$id');
    final meals = data['meals'] as List<dynamic>?;
    if (meals == null || meals.isEmpty) {
      throw Exception('Meal not found');
    }
    return RecipeModel.fromJson(meals.first as Map<String, dynamic>);
  }

  Future<List<RecipeModel>> searchMeals(String query) async {
    final data = await _get('/search.php?s=$query');
    final meals = data['meals'] as List<dynamic>?;
    if (meals == null) return [];
    return meals
        .map((e) => RecipeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeModel>> getMealsByCategory(
    String category, {
    int limit = 12,
  }) async {
    final data = await _get('/filter.php?c=$category');
    final meals = data['meals'] as List<dynamic>?;
    if (meals == null) return [];

    final ids = meals.take(limit).map((e) => e['idMeal'] as String).toList();
    final results = <RecipeModel>[];
    for (final id in ids) {
      try {
        results.add(await getMealById(id));
      } catch (_) {
        // ignore failures for individual meals
      }
    }
    return results;
  }

  Future<List<String>> getMealIdsByCategory(String category) async {
    final data = await _get('/filter.php?c=$category');
    final meals = data['meals'] as List<dynamic>?;
    if (meals == null) return [];
    return meals.map((e) => e['idMeal'] as String).toList();
  }

  Future<List<RecipeModel>> getMealsByArea(
    String area, {
    int limit = 12,
  }) async {
    final data = await _get('/filter.php?a=$area');
    final meals = data['meals'] as List<dynamic>?;
    if (meals == null) return [];

    final ids = meals.take(limit * 2).map((e) => e['idMeal'] as String).toList();
    ids.shuffle(Random());
    final results = <RecipeModel>[];
    for (final id in ids.take(limit)) {
      try {
        results.add(await getMealById(id));
      } catch (_) {
        // ignore failures
      }
    }
    return results;
  }
}

