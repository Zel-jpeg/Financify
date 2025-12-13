import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../home/main_navigation_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background image
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/onboarding/login-bg.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            // Content
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.appName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF21393B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your finances, finally simplified.',
                            style: TextStyle(color: Color(0xFF21393B)),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome Back!',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Please sign in using your DNSC Provided Account',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () => _handleGoogleSignIn(
                                              context,
                                              authProvider,
                                            ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      elevation: 6,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                'Signing in...',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Google Logo Image
                                              Image.asset(
                                                'assets/images/icons/google-logo.png',
                                                height: 24,
                                                width: 24,
                                                errorBuilder: (context, error, stackTrace) {
                                                  // Fallback to icon if image not found
                                                  return const Icon(
                                                    Icons.g_mobiledata,
                                                    size: 28,
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Continue using Google',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: OutlinedButton.icon(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () => _handleGuestSignIn(context, authProvider),
                                    icon: const Icon(Icons.person_outline),
                                    label: const Text(
                                      'Continue as guest',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: const BorderSide(
                                        color: Colors.black12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      backgroundColor: Colors.grey.shade50,
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (authProvider.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      authProvider.errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/logo/logo-circle.png',
                                      height: 28,
                                      width: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Financify',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    debugPrint('[SignIn] Starting Google sign-in...');
    
    final success = await authProvider.signInWithGoogle();
    
    if (success && context.mounted) {
      debugPrint('[SignIn] ✓ Google sign-in successful, refreshing data...');
      
      // Show loading indicator while refreshing data
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // ✨ AUTO-REFRESH ALL DATA AFTER LOGIN ✨
      await authProvider.refreshAllData(context);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      debugPrint('[SignIn] ✓ Data refreshed, navigating to main screen...');
      
      // Navigate to main screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } else if (context.mounted) {
      debugPrint('[SignIn] ✗ Google sign-in failed');
      final msg = authProvider.errorMessage ?? 'Sign in failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGuestSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    debugPrint('[SignIn] Starting guest mode...');
    
    final success = await authProvider.continueAsGuest();
    
    if (success && context.mounted) {
      debugPrint('[SignIn] ✓ Guest mode enabled, refreshing data...');
      
      // Show loading indicator while refreshing data
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // ✨ AUTO-REFRESH ALL DATA FOR GUEST USER ✨
      await authProvider.refreshAllData(context);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      debugPrint('[SignIn] ✓ Data refreshed, navigating to main screen...');
      
      // Navigate to main screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } else if (context.mounted) {
      debugPrint('[SignIn] ✗ Guest mode failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to continue as guest. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}