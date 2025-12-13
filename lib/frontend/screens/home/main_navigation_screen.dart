import 'package:flutter/material.dart';
import '../more/more_screen.dart';
import '../statistics/statistics_screen.dart';
import 'home_screen.dart';

/// Simple bottom-nav shell to move between Home, Statistics, and More (Settings/Profile).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 1; // default to Home

  final List<Widget> _pages = const [
    StatisticsScreen(),
    HomeScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFF9ADBBF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.bar_chart,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                  selectedColor: const Color(0xFF0B8A62),
                ),
                _NavItem(
                  icon: Icons.home,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                  selectedColor: const Color(0xFF0B8A62),
                ),
                _NavItem(
                  icon: Icons.grid_view,
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                  selectedColor: const Color(0xFF0B8A62),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFF6CC7B2),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: selected
              ? selectedColor
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: selected
              ? Colors.white
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : selectedColor,
          size: 28,
        ),
      ),
    );
  }
}

