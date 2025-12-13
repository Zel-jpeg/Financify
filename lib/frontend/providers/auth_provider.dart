import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/supabase_constants.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Google Sign-In (clean, simple)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Important: must be the Web client ID that matches the one configured in Supabase Google provider
    serverClientId: SupabaseConstants.googleWebClientId.isEmpty
        ? null
        : SupabaseConstants.googleWebClientId,
  );

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  static const _guestKey = 'guest_mode';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // -------------------------
  // Google Sign In
  // -------------------------
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint("[Auth] Starting Google sign-in...");
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Step 1 — User chooses Google account
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("[Auth] User cancelled Google sign-in.");
        _isLoading = false;
        notifyListeners();
        return false; // user cancelled
      }
      debugPrint("[Auth] Google user selected: ${googleUser.email}");

      // Step 2 — Check domain restriction
      if (!googleUser.email.endsWith('@dnsc.edu.ph')) {
        _errorMessage = "Only @dnsc.edu.ph email addresses are allowed.";
        await _googleSignIn.signOut();
        _isLoading = false;
        notifyListeners();
        debugPrint("[Auth] Domain check failed for ${googleUser.email}");
        return false;
      }
      debugPrint("[Auth] Domain check passed.");

      // Step 3 — Get tokens
      final googleAuth = await googleUser.authentication;
      debugPrint("[Auth] Retrieved tokens. IdToken null? ${googleAuth.idToken == null}, AccessToken null? ${googleAuth.accessToken == null}");

      // Step 4 — Log into Supabase
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      _isLoading = false;
      notifyListeners();
      final ok = response.user != null;
      debugPrint("[Auth] Supabase sign-in ${ok ? "succeeded" : "failed"}.");
      return ok;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Sign In failed: $e";
      notifyListeners();
      debugPrint("[Auth] Sign-in error: $e");
      return false;
    }
  }

  // -------------------------
  // Guest / Anonymous Mode
  // -------------------------
  Future<bool> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, true);
    return true;   // No change, stays working
  }

  // -------------------------
  // Sign Out
  // -------------------------
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestKey);
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestKey) ?? false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
