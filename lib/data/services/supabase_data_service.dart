import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDataService {
  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetch(String table) async {
    final uid = currentUserId;
    if (uid == null) return [];
    final res = await _client
        .from(table)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> insert(String table, Map<String, dynamic> data) async {
    await _client.from(table).insert(data);
  }

  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    await _client.from(table).update(data).eq('id', id);
  }

  Future<void> upsert(String table, Map<String, dynamic> data) async {
    await _client.from(table).upsert(data);
  }

  Future<void> delete(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }
}

