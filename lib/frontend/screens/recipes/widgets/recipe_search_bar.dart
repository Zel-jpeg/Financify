import 'package:flutter/material.dart';

class RecipeSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  const RecipeSearchBar({super.key, required this.onSearch});

  @override
  State<RecipeSearchBar> createState() => _RecipeSearchBarState();
}

class _RecipeSearchBarState extends State<RecipeSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Search budget meals...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE8F8EF).withOpacity(0.15)
            : Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: widget.onSearch,
    );
  }
}

