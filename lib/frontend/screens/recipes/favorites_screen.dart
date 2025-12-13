import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/recipe_provider.dart';
import 'widgets/recipe_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);
    final favorites = provider.favoriteRecipes;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Recipes')),
      body: favorites.isEmpty
          ? const Center(child: Text('No favorites yet'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                return RecipeCard(
                  recipe: favorites[index],
                  compact: true,
                );
              },
            ),
    );
  }
}

