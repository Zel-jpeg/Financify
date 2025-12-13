class RecipeIngredient {
  final String name;
  final String measure;

  const RecipeIngredient({required this.name, required this.measure});
}

class RecipeModel {
  final String id;
  final String name;
  final String category;
  final String area;
  final String instructions;
  final String thumbnail;
  final List<RecipeIngredient> ingredients;

  const RecipeModel({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.instructions,
    required this.thumbnail,
    required this.ingredients,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    final ingredients = <RecipeIngredient>[];
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'] as String?;
      final measure = json['strMeasure$i'] as String?;
      if (ingredient != null &&
          ingredient.trim().isNotEmpty &&
          measure != null &&
          measure.trim().isNotEmpty) {
        ingredients.add(
          RecipeIngredient(
            name: ingredient.trim(),
            measure: measure.trim(),
          ),
        );
      }
    }

    return RecipeModel(
      id: json['idMeal'] as String,
      name: json['strMeal'] as String? ?? 'Untitled',
      category: json['strCategory'] as String? ?? 'Budget Meal',
      area: json['strArea'] as String? ?? '',
      instructions: json['strInstructions'] as String? ?? '',
      thumbnail: json['strMealThumb'] as String? ?? '',
      ingredients: ingredients,
    );
  }
}

