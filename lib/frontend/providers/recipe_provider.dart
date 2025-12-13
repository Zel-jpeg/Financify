import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../data/models/recipe_model.dart';
import '../../data/services/meal_db_service.dart';
import '../../data/services/supabase_data_service.dart';

class RecipeProvider extends ChangeNotifier {
  RecipeProvider({MealDbService? service})
      : _service = service ?? MealDbService();

  final MealDbService _service;
  final SupabaseDataService _supabase = SupabaseDataService();
  static const _prefsKey = 'favorite_recipes';
  static const _favoritesCacheKey = 'favorite_recipes_cache';
  static const _favoriteOpsKey = 'favorite_ops_queue';
  static const _featuredKey = 'featured_recipe';
  static const _featuredDateKey = 'featured_recipe_date';

  bool _loading = false;
  bool get isLoading => _loading;
  bool _loadingMore = false;
  bool get isLoadingMore => _loadingMore;
  bool _loadingFavorites = false;
  bool get isLoadingFavorites => _loadingFavorites;

  RecipeModel? _featuredMeal;
  RecipeModel? get featuredMeal => _featuredMeal;

  List<RecipeModel> _recipes = [];
  List<RecipeModel> get recipes => _recipes;
  final Set<String> _seenRecipeIds = {};
  List<String> _categoryIds = [];
  int _page = 0;
  final int _pageSize = 10;
  bool _canLoadMore = true;
  bool get canLoadMore => _canLoadMore;

  final Map<String, RecipeModel> _favorites = {};
  List<RecipeModel> get favoriteRecipes => _favorites.values.toList();

  String _selectedCategory = 'Chicken';
  String get selectedCategory => _selectedCategory;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFavorites();
    await loadRecipes();
  }

  Future<void> loadRecipes({String? category}) async {
    _loading = true;
    notifyListeners();
    try {
      if (category != null) {
        _selectedCategory = category;
      } else {
        _selectedCategory = 'All';
      }
      _page = 0;
      _canLoadMore = true;
      _seenRecipeIds.clear();
      _recipes = [];

      await _loadFeaturedForToday();
      final filipinoMeals =
          await _service.getMealsByArea('Filipino', limit: 20);
      for (final meal in filipinoMeals) {
        if (_seenRecipeIds.add(meal.id)) {
          _recipes.add(meal);
        }
      }

      if (_selectedCategory == 'All') {
        final cats = ['Chicken', 'Seafood', 'Beef', 'Vegetarian'];
        final combined = <String>[];
        for (final c in cats) {
          final ids = await _service.getMealIdsByCategory(c);
          combined.addAll(ids);
        }
        _categoryIds = combined.toSet().toList();
      } else {
        _categoryIds = await _service.getMealIdsByCategory(_selectedCategory);
      }
      _categoryIds.removeWhere((id) => _seenRecipeIds.contains(id));

      await _loadNextPage();
      await _syncFavoriteOps();
      await _pullFavoritesFromRemote();
    } catch (_) {
      _recipes = [];
      await _loadFavoritesCache();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      await loadRecipes();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      _recipes = await _service.searchMeals(query.trim());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(RecipeModel recipe) async {
    final wasFavorite = _favorites.containsKey(recipe.id);
    if (wasFavorite) {
      _favorites.remove(recipe.id);
    } else {
      _favorites[recipe.id] = recipe;
    }
    await _persistFavorites();
    notifyListeners();

    final op = wasFavorite ? 'delete' : 'upsert';
    final uid = await _supabase.getCurrentUserId();
    if (uid == null) return;
    final record = {
      'user_id': uid,
      'recipe_id': recipe.id,
      'recipe': _toJson(recipe),
    };

    final online = await _trySupabaseOp(() async {
      if (op == 'delete') {
        await _supabase.delete('favorite_recipes', recipe.id);
      } else {
        await _supabase.upsert('favorite_recipes', record);
      }
    });
    if (!online) {
      await _enqueueFavoriteOp(op, record);
    }
  }

  bool isFavorite(String id) => _favorites.containsKey(id);

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_canLoadMore) return;
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_page * _pageSize >= _categoryIds.length) {
      _canLoadMore = false;
      return;
    }
    _loadingMore = true;
    notifyListeners();
    final start = _page * _pageSize;
    final batchIds = _categoryIds.skip(start).take(_pageSize).toList();
    for (final id in batchIds) {
      try {
        final recipe = await _service.getMealById(id);
        if (_seenRecipeIds.add(recipe.id)) {
          _recipes.add(recipe);
        }
      } catch (_) {
        // ignore failed fetches
      }
    }
    _page++;
    if (_page * _pageSize >= _categoryIds.length) {
      _canLoadMore = false;
    }
    _loadingMore = false;
    notifyListeners();
  }

  Future<void> _loadFeaturedForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final savedDate = prefs.getString(_featuredDateKey);
    final savedJson = prefs.getString(_featuredKey);

    if (savedDate == today && savedJson != null) {
      final map = jsonDecode(savedJson) as Map<String, dynamic>;
      _featuredMeal = RecipeModel.fromJson(map);
      return;
    }

    final filipinoMeals =
        await _service.getMealsByArea('Filipino', limit: 10);
    if (filipinoMeals.isNotEmpty) {
      _featuredMeal = filipinoMeals.first;
    } else {
      _featuredMeal = await _service.getRandomMeal();
    }

    await prefs.setString(_featuredDateKey, today);
    await prefs.setString(_featuredKey, jsonEncode(_toJson(_featuredMeal!)));
  }

  Map<String, dynamic> _toJson(RecipeModel recipe) => {
        'idMeal': recipe.id,
        'strMeal': recipe.name,
        'strCategory': recipe.category,
        'strArea': recipe.area,
        'strInstructions': recipe.instructions,
        'strMealThumb': recipe.thumbnail,
        for (int i = 0; i < recipe.ingredients.length; i++) ...{
          'strIngredient${i + 1}': recipe.ingredients[i].name,
          'strMeasure${i + 1}': recipe.ingredients[i].measure,
        }
      };

  Future<void> _loadFavorites() async {
    await _loadFavoritesCache();
    await _pullFavoritesFromRemote();
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _favorites.keys.toList());
    final favList = _favorites.values.map((r) => _toJson(r)).toList();
    await prefs.setString(_favoritesCacheKey, jsonEncode(favList));
  }

  Future<void> _loadFavoritesCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_favoritesCacheKey);
    if (cached == null) return;
    try {
      final list = (jsonDecode(cached) as List)
          .cast<Map<String, dynamic>>()
          .map(RecipeModel.fromJson);
      _favorites.clear();
      for (final r in list) {
        _favorites[r.id] = r;
      }
    } catch (_) {
      // ignore corrupt cache
    }
    notifyListeners();
  }

  Future<void> _pullFavoritesFromRemote() async {
    _loadingFavorites = true;
    notifyListeners();
    final ok = await _trySupabaseOp(() async {
      final rows = await _supabase.fetch('favorite_recipes');
      _favorites.clear();
      for (final row in rows) {
        final recipeMap = (row['recipe'] as Map<String, dynamic>);
        final recipe = RecipeModel.fromJson(recipeMap);
        _favorites[recipe.id] = recipe;
      }
      await _persistFavorites();
    });
    _loadingFavorites = false;
    notifyListeners();
    if (!ok) return;
  }

  Future<void> _enqueueFavoriteOp(String op, Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoriteOpsKey);
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    list.add({'op': op, 'record': record});
    await prefs.setString(_favoriteOpsKey, jsonEncode(list));
  }

  Future<void> _syncFavoriteOps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoriteOpsKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final remaining = <Map<String, dynamic>>[];
    for (final item in list) {
      final op = item['op'] as String;
      final record = (item['record'] as Map<String, dynamic>);
      final success = await _trySupabaseOp(() async {
        if (op == 'delete') {
          await _supabase.delete('favorite_recipes', record['recipe_id'] as String);
        } else {
          await _supabase.upsert('favorite_recipes', record);
        }
      });
      if (!success) {
        remaining.add(item);
        break;
      }
    }
    await prefs.setString(_favoriteOpsKey, jsonEncode(remaining));
  }

  Future<bool> _trySupabaseOp(Future<void> Function() fn) async {
    try {
      await fn();
      return true;
    } catch (_) {
      return false;
    }
  }
}

