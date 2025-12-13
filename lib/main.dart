import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_constants.dart';
import 'frontend/providers/auth_provider.dart';
import 'frontend/providers/budget_provider.dart';
import 'frontend/providers/connectivity_provider.dart';
import 'frontend/providers/savings_provider.dart';
import 'frontend/providers/transaction_provider.dart';
import 'frontend/providers/recipe_provider.dart';
import 'frontend/providers/currency_provider.dart';
import 'frontend/providers/theme_provider.dart';
import 'frontend/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );
  
  // Initialize theme provider to load saved preference
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  
  // Initialize auth provider to load guest mode state
  final authProvider = AuthProvider();
  await authProvider.initialize();
  
  runApp(MyApp(
    themeProvider: themeProvider,
    authProvider: authProvider,
  ));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  
  const MyApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProxyProvider<ConnectivityProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, connectivity, previous) =>
              previous ?? TransactionProvider()..setConnectivity(connectivity)..load(),
        ),
        ChangeNotifierProxyProvider<ConnectivityProvider, BudgetProvider>(
          create: (_) => BudgetProvider(),
          update: (_, connectivity, previous) =>
              previous ?? BudgetProvider()..setConnectivity(connectivity)..load(),
        ),
        ChangeNotifierProxyProvider<ConnectivityProvider, SavingsProvider>(
          create: (_) => SavingsProvider(),
          update: (_, connectivity, previous) =>
              previous ?? SavingsProvider()..setConnectivity(connectivity)..load(),
        ),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Financify',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.mode,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}