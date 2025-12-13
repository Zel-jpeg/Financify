import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/supabase_constants.dart';
import 'transaction_provider.dart';
import 'budget_provider.dart';
import 'savings_provider.dart';
import '../../data/datasources/local/guest_user_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: SupabaseConstants.googleWebClientId.isEmpty
        ? null
        : SupabaseConstants.googleWebClientId,
  );

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Guest mode state
  bool _isGuestMode = false;
  bool get isGuestMode => _isGuestMode;
  
  String? _guestUserId;
  String? get guestUserId => _guestUserId;

  /// Get the effective user ID (guest ID if in guest mode, otherwise Supabase user ID)
  String? get effectiveUserId {
    if (_isGuestMode && _guestUserId != null) {
      return _guestUserId;
    }
    return currentUser?.id;
  }

  /// Initialize provider and load guest mode state
  Future<void> initialize() async {
    _isGuestMode = await GuestUserService.isGuestMode();
    if (_isGuestMode) {
      _guestUserId = await GuestUserService.getGuestUserId();
      debugPrint('[AuthProvider] Initialized in guest mode: $_guestUserId');
    } else if (currentUser != null) {
      debugPrint('[AuthProvider] Initialized with user: ${currentUser!.id}');
    }
    notifyListeners();
  }

  // -------------------------
  // Google Sign In
  // -------------------------
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint("[AuthProvider] Starting Google sign-in...");
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("[AuthProvider] User cancelled Google sign-in.");
        _isLoading = false;
        notifyListeners();
        return false;
      }
      debugPrint("[AuthProvider] Google user selected: ${googleUser.email}");

      if (!googleUser.email.endsWith('@dnsc.edu.ph')) {
        _errorMessage = "Only @dnsc.edu.ph email addresses are allowed.";
        await _googleSignIn.signOut();
        _isLoading = false;
        notifyListeners();
        debugPrint("[AuthProvider] Domain check failed for ${googleUser.email}");
        return false;
      }
      debugPrint("[AuthProvider] Domain check passed.");

      final googleAuth = await googleUser.authentication;
      debugPrint("[AuthProvider] Retrieved tokens.");

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      // Disable guest mode when signing in with Google
      await GuestUserService.disableGuestMode();
      _isGuestMode = false;
      _guestUserId = null;

      _isLoading = false;
      final ok = response.user != null;
      debugPrint("[AuthProvider] Supabase sign-in ${ok ? "succeeded" : "failed"}.");
      if (ok) {
        debugPrint("[AuthProvider] Logged in as: ${response.user!.id}");
      }
      notifyListeners();
      return ok;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Sign In failed: $e";
      notifyListeners();
      debugPrint("[AuthProvider] Sign-in error: $e");
      return false;
    }
  }

  // -------------------------
  // Guest / Anonymous Mode
  // -------------------------
  Future<bool> continueAsGuest() async {
    try {
      debugPrint("[AuthProvider] Continuing as guest...");
      _guestUserId = await GuestUserService.enableGuestMode();
      _isGuestMode = true;
      debugPrint("[AuthProvider] Guest user ID: $_guestUserId");
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[AuthProvider] Failed to enable guest mode: $e");
      return false;
    }
  }

  // -------------------------
  // Sign Out
  // -------------------------
  Future<void> signOut() async {
    debugPrint("[AuthProvider] Signing out...");
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
    
    // Clear guest mode
    await GuestUserService.disableGuestMode();
    _isGuestMode = false;
    _guestUserId = null;
    
    _errorMessage = null;
    debugPrint("[AuthProvider] Signed out successfully");
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh all data after login/logout
  /// Call this from your UI after successful authentication changes
  Future<void> refreshAllData(BuildContext context) async {
    debugPrint("[AuthProvider] Refreshing all data providers...");
    
    try {
      // Get all providers
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final savingsProvider = Provider.of<SavingsProvider>(context, listen: false);
      
      // Reload all data in parallel for faster refresh
      await Future.wait([
        transactionProvider.load(),
        budgetProvider.load(),
        savingsProvider.load(),
      ]);
      
      debugPrint("[AuthProvider] ✓ All data refreshed successfully");
    } catch (e) {
      debugPrint("[AuthProvider] ✗ Error refreshing data: $e");
    }
  }
}