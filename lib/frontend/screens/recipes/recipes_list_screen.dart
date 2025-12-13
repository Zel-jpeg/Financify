import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/recipe_model.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../recipes/favorites_screen.dart';
import 'widgets/recipe_card.dart';
import 'widgets/recipe_search_bar.dart';
import '../../widgets/animated_entry.dart';

class RecipesListScreen extends StatefulWidget {
  const RecipesListScreen({super.key});

  @override
  State<RecipesListScreen> createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  final List<String> _categories = ['All', 'Chicken', 'Seafood', 'Beef', 'Vegetarian'];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().initialize();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<RecipeProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: provider.loadRecipes,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (isOffline)
                  AnimatedEntry(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Offline mode: showing cached recipes/favorites. Connect to refresh.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ),
                AnimatedEntry(
                  child: RecipeSearchBar(onSearch: provider.search),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final selected = provider.selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) =>
                            provider.loadRecipes(category: category == 'All' ? null : category),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedEntry(
                  child: _buildFeatured(provider.featuredMeal, isOffline),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recipe recommendations',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  GridView.builder(
                    itemCount: provider.recipes.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (context, index) {
                      final recipe = provider.recipes[index];
                      return AnimatedEntry(
                        index: index,
                        child: RecipeCard(
                          recipe: recipe,
                          compact: true,
                          offlineImage: isOffline,
                        ),
                      );
                    },
                  ),
                if (provider.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatured(RecipeModel? recipe, bool isOffline) {
    if (recipe == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipe for you today',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        RecipeCard(
          recipe: recipe,
          offlineImage: isOffline,
        ),
      ],
    );
  }

  void _onScroll() {
    final provider = context.read<RecipeProvider>();
    if (!provider.canLoadMore || provider.isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      provider.loadMore();
    }
  }
}

