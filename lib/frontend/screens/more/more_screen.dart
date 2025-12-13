import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_entry.dart';
import '../auth/signin_screen.dart';
import '../currency/currency_converter_screen.dart';
import '../recipes/recipes_list_screen.dart';
import '../settings/settings_screen.dart';
import 'about_us_screen.dart';
import 'widgets/more_menu_item.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.9,
                children: [
                  AnimatedEntry(
                    index: 0,
                    child: MoreMenuItem(
                      icon: Icons.restaurant_menu,
                      title: 'Budget',
                      subtitle: 'Recipe Ideas',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecipesListScreen(),
                        ),
                      ),
                    ),
                  ),
                  AnimatedEntry(
                    index: 1,
                    child: MoreMenuItem(
                      icon: Icons.currency_exchange,
                      title: 'Currency',
                      subtitle: 'Converter',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CurrencyConverterScreen(),
                        ),
                      ),
                    ),
                  ),
                  AnimatedEntry(
                    index: 2,
                    child: MoreMenuItem(
                      icon: Icons.settings,
                      title: 'Settings',
                      subtitle: 'Profile & Preferences',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                  AnimatedEntry(
                    index: 3,
                    child: MoreMenuItem(
                      icon: Icons.info_outline,
                      title: 'About Us',
                      subtitle: 'Learn more',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AboutUsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Log out'),
                          content: const Text('Are you sure you want to log out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Log out'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (!confirmed) return;
                  await auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const SignInScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}

