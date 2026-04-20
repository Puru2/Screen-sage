import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StreakRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  DocumentReference get _doc =>
      _db.collection('users').doc(_uid).collection('streak').doc('data');

  // ── Fetch ─────────────────────────────────────────────────────
  Future<StreakData> getData() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      final initial = StreakData.empty();
      await _doc.set(initial.toMap());
      return initial;
    }
    return StreakData.fromMap(snap.data() as Map<String, dynamic>);
  }

  Stream<StreakData> watchData() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return StreakData.empty();
      return StreakData.fromMap(snap.data() as Map<String, dynamic>);
    });
  }

  // ── Called after every completed session ──────────────────────
  Future<StreakData> recordSession() async {
    debugPrint('🔥 Recording session for streak...');

    return await _db.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final existing = snap.exists
          ? StreakData.fromMap(snap.data() as Map<String, dynamic>)
          : StreakData.empty();

      final today = _todayString();
      final yesterday =
          _dateString(DateTime.now().subtract(const Duration(days: 1)));

      // Already recorded today — no change
      if (existing.lastSessionDate == today) {
        debugPrint('✅ Streak already recorded today');
        return existing;
      }

      int newStreak;
      if (existing.lastSessionDate == yesterday) {
        // Consecutive day — increment
        newStreak = existing.currentStreak + 1;
        debugPrint('🔥 Streak extended: $newStreak days');
      } else if (existing.lastSessionDate == null) {
        // First ever session
        newStreak = 1;
        debugPrint('🔥 First session — streak starts!');
      } else {
        // Missed day(s) — reset
        newStreak = 1;
        debugPrint('💔 Streak broken — reset to 1');
      }

      final newLongest = newStreak > existing.longestStreak
          ? newStreak
          : existing.longestStreak;

      final updated = StreakData(
        currentStreak: newStreak,
        longestStreak: newLongest,
        lastSessionDate: today,
        totalDays: existing.totalDays + 1,
      );

      tx.set(_doc, updated.toMap());
      return updated;
    });
  }

  // ── Check if streak is at risk (no session yet today) ─────────
  Future<bool> isStreakAtRisk() async {
    final data = await getData();
    if (data.currentStreak == 0) return false;

    final today = _todayString();
    final yesterday =
        _dateString(DateTime.now().subtract(const Duration(days: 1)));

    // If last session was yesterday and no session today → at risk
    return data.lastSessionDate == yesterday;
  }

  String _todayString() => _dateString(DateTime.now());

  String _dateString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ── Model ─────────────────────────────────────────────────────────
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final String? lastSessionDate;
  final int totalDays;

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSessionDate,
    required this.totalDays,
  });

  factory StreakData.empty() => const StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastSessionDate: null,
        totalDays: 0,
      );

  factory StreakData.fromMap(Map<String, dynamic> map) => StreakData(
        currentStreak: map['current_streak'] as int? ?? 0,
        longestStreak: map['longest_streak'] as int? ?? 0,
        lastSessionDate: map['last_session_date'] as String?,
        totalDays: map['total_days'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_session_date': lastSessionDate,
        'total_days': totalDays,
        'updated_at': FieldValue.serverTimestamp(),
      };

  // Milestone checks — used for badge UI
  bool get isOnFire => currentStreak >= 7;
  bool get isLegendary => currentStreak >= 30;
  String get emoji {
    if (currentStreak == 0) return '🌱';
    if (currentStreak < 3) return '⚡';
    if (currentStreak < 7) return '🔥';
    if (currentStreak < 14) return '🚀';
    if (currentStreak < 30) return '💎';
    return '👑';
  }
}
