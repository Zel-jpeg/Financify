import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/local/guest_user_service.dart';

class SupabaseDataService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Get the effective user ID (guest or real user)
  /// This is THE method all providers should use
  Future<String?> getCurrentUserId() async {
    final isGuest = await GuestUserService.isGuestMode();
    if (isGuest) {
      return await GuestUserService.getGuestUserId();
    }
    return _client.auth.currentUser?.id;
  }

  Future<List<Map<String, dynamic>>> fetch(String table) async {
    final uid = await getCurrentUserId();
    if (uid == null) return [];
    
    // Skip Supabase if in guest mode (data only exists locally)
    final isGuest = await GuestUserService.isGuestMode();
    if (isGuest) {
      return []; // Guest data is only local
    }
    
    final res = await _client
        .from(table)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> insert(String table, Map<String, dynamic> data) async {
    // Skip Supabase if in guest mode
    final isGuest = await GuestUserService.isGuestMode();
    if (isGuest) {
      return; // Guest mode: only save locally
    }
    
    await _client.from(table).insert(data);
  }

  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    // Skip Supabase if in guest mode
    final isGuest = await GuestUserService.isGuestMode();
    if (isGuest) {
      return; // Guest mode: only save locally
    }
    
    await _client.from(table).update(data).eq('id', id);
  }

  Future<void> upsert(String table, Map<String, dynamic> data) async {
    // Skip Supabase if in guest mode
    final isGuest = await GuestUserService.isGuestMode();
    if (isGuest) {
      return; // Guest mode: only save locally
    }
    
    await _client.from(table).upsert(data);
  }

  Future<void> delete(String table, String id) async {
    // Skip Supabase if in guest mode
    final isGuest = await GuestUserService.isGuestMode();
    if (isGuest) {
      return; // Guest mode: only save locally
    }
    
    await _client.from(table).delete().eq('id', id);
  }
}