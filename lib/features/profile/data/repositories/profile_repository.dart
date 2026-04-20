import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  // Called once after login to fetch or create profile
  Future<Map<String, dynamic>?> getProfile() async {
    final response =
        await _client.from('profiles').select().eq('id', _uid).maybeSingle();
    return response;
  }

  Future<void> updateDisplayName(String name) async {
    await _client
        .from('profiles')
        .update({'display_name': name}).eq('id', _uid);
  }

  // Streak data
  Future<Map<String, dynamic>?> getStreak() async {
    final response = await _client
        .from('streaks')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    return response;
  }

  // Called after every completed session
  Future<void> updateStreak() async {
    final today =
        DateTime.now().toIso8601String().split('T')[0]; // 'YYYY-MM-DD'

    final existing = await getStreak();
    if (existing == null) return;

    final lastDate = existing['last_session_date'] as String?;
    final current = existing['current_streak'] as int? ?? 0;
    final longest = existing['longest_streak'] as int? ?? 0;

    int newStreak;

    if (lastDate == null) {
      newStreak = 1;
    } else {
      final last = DateTime.parse(lastDate);
      final now = DateTime.now();
      final diff = now.difference(last).inDays;

      if (diff == 0) {
        return; // already updated today
      } else if (diff == 1) {
        newStreak = current + 1; // consecutive day
      } else {
        newStreak = 1; // streak broken
      }
    }

    await _client.from('streaks').update({
      'current_streak': newStreak,
      'longest_streak': newStreak > longest ? newStreak : longest,
      'last_session_date': today,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', _uid);
  }
}
