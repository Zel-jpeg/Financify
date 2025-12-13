import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/recipe_model.dart';
import '../../../providers/recipe_provider.dart';
import '../../recipes/recipe_detail_screen.dart';

class RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool compact;
  final bool offlineImage;
  const RecipeCard({
    super.key,
    required this.recipe,
    this.compact = false,
    this.offlineImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);
    final isFavorite = provider.isFavorite(recipe.id);
    final displayName = _limitWords(recipe.name, 2);
    final hasCategory = recipe.category.trim().isNotEmpty;
    final hasArea = recipe.area.trim().isNotEmpty;
    String? subtitle;
    if (hasCategory && hasArea) {
      subtitle = '${recipe.category} • ${recipe.area}';
    } else if (hasCategory) {
      subtitle = recipe.category;
    } else if (hasArea) {
      subtitle = recipe.area;
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipe: recipe),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: compact ? 1.2 : 1.6,
                    child: offlineImage
                        ? Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text(
                              'Image unavailable offline',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : Image.network(
                            recipe.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text(
                                'Image unavailable',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => provider.toggleFavorite(recipe),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).cardColor,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _limitWords(String text, int maxWords) {
  final parts = text.trim().split(RegExp(r'\s+'));
  if (parts.length <= maxWords) return text.trim();
  return '${parts.take(maxWords).join(' ')}...';
}

