import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to manage guest user identity
class GuestUserService {
  static const String _guestModeKey = 'guest_mode';
  static const String _guestUserIdKey = 'guest_user_id';
  static const _uuid = Uuid();

  /// Check if currently in guest mode
  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  /// Get the guest user ID (creates one if it doesn't exist)
  static Future<String> getGuestUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString(_guestUserIdKey);
    
    if (guestId == null || guestId.isEmpty) {
      // Generate a new guest user ID
      guestId = 'guest_${_uuid.v4()}';
      await prefs.setString(_guestUserIdKey, guestId);
    }
    
    return guestId;
  }

  /// Enable guest mode and create/get guest user ID
  static Future<String> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    return await getGuestUserId();
  }

  /// Disable guest mode (but keep guest user ID for returning users)
  static Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
  }

  /// Clear all guest data (use when signing out permanently)
  static Future<void> clearGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
    await prefs.remove(_guestUserIdKey);
  }
}