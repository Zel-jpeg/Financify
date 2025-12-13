import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/signin_screen.dart';
import '../home/main_navigation_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../../data/datasources/local/guest_user_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Add a small delay to ensure everything is initialized
      await Future.delayed(const Duration(milliseconds: 500));

      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

      // Use GuestUserService instead of AuthProvider
      final isGuest = await GuestUserService.isGuestMode();
      final supaUser = Supabase.instance.client.auth.currentUser;

      debugPrint('[Splash] Onboarding seen: $seenOnboarding');
      debugPrint('[Splash] Is guest: $isGuest');
      debugPrint('[Splash] Has Supabase user: ${supaUser != null}');

      // Add another small delay before navigation
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      if (!seenOnboarding) {
        debugPrint('[Splash] → Navigating to Onboarding');
        _go(const OnboardingScreen());
        return;
      }

      if (supaUser != null || isGuest) {
        debugPrint('[Splash] → Navigating to Main Navigation');
        _go(const MainNavigationScreen());
      } else {
        debugPrint('[Splash] → Navigating to Sign In');
        _go(const SignInScreen());
      }
    } catch (e, stackTrace) {
      debugPrint('[Splash] Error during bootstrap: $e');
      debugPrint('[Splash] Stack trace: $stackTrace');
      
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });

      // Fallback: Navigate to sign in after showing error
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _go(const SignInScreen());
      }
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: _hasError ? _buildErrorView() : _buildLoadingView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogo(),
        const SizedBox(height: 24),
        
        Text(
          'Financify',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        
        CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        
        Text(
          'Loading...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo/logo-circle.png',
      height: 120,
      width: 120,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[Splash] Error loading logo: $error');
        return Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.account_balance_wallet,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Redirecting to sign in...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}