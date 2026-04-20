import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EarnedTimeRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  DocumentReference get _doc =>
      _db.collection('users').doc(_uid).collection('earned_time').doc('data');

  // ── Fetch ─────────────────────────────────────────────────────
  Future<EarnedTimeData> getData() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      // First time — create with zero balance
      final initial = EarnedTimeData.empty();
      await _doc.set(initial.toMap());
      return initial;
    }
    return EarnedTimeData.fromMap(snap.data() as Map<String, dynamic>);
  }

  // Real-time stream for live balance updates
  Stream<EarnedTimeData> watchData() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return EarnedTimeData.empty();
      return EarnedTimeData.fromMap(snap.data() as Map<String, dynamic>);
    });
  }

  // ── Add earned minutes (called after session completes) ───────
  Future<void> addEarnedMinutes(int mins) async {
    debugPrint('💰 Adding $mins earned minutes');
    await _doc.set({
      'balance_mins': FieldValue.increment(mins),
      'lifetime_earned': FieldValue.increment(mins),
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ Earned balance updated +$mins');
  }

  // ── Spend earned time (start free time session) ───────────────
  Future<bool> spendMinutes(int mins) async {
    debugPrint('💸 Spending $mins minutes of earned time');

    return await _db.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final data = snap.exists
          ? EarnedTimeData.fromMap(snap.data() as Map<String, dynamic>)
          : EarnedTimeData.empty();

      if (data.balanceMins < mins) {
        debugPrint('❌ Insufficient balance: ${data.balanceMins} < $mins');
        return false;
      }

      final now = DateTime.now();
      final endsAt = now.add(Duration(minutes: mins));

      tx.set(
        _doc,
        {
          'balance_mins': FieldValue.increment(-mins),
          'lifetime_spent': FieldValue.increment(mins),
          'last_updated': FieldValue.serverTimestamp(),
          'active_session': {
            'is_active': true,
            'started_at': Timestamp.fromDate(now),
            'duration_mins': mins,
            'ends_at': Timestamp.fromDate(endsAt),
          },
        },
        SetOptions(merge: true),
      );
      debugPrint('✅ Spent $mins minutes — free until $endsAt');
      return true;
    });
  }

  // ── End free time session ─────────────────────────────────────
  Future<void> endFreeSession() async {
    debugPrint('🔒 Ending free time session');
    await _doc.set({
      'active_session': {
        'is_active': false,
        'started_at': null,
        'duration_mins': 0,
        'ends_at': null,
      },
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Cap balance at 180 mins (3hr max bank) ────────────────────
  Future<void> capBalance() async {
    final snap = await _doc.get();
    if (!snap.exists) return;
    final data = EarnedTimeData.fromMap(snap.data() as Map<String, dynamic>);
    if (data.balanceMins > 180) {
      await _doc.update({'balance_mins': 180});
    }
  }
}

// ── Data Model ────────────────────────────────────────────────────
class EarnedTimeData {
  final int balanceMins;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final ActiveFreeSession? activeSession;

  const EarnedTimeData({
    required this.balanceMins,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    this.activeSession,
  });

  factory EarnedTimeData.empty() => const EarnedTimeData(
        balanceMins: 0,
        lifetimeEarned: 0,
        lifetimeSpent: 0,
        activeSession: null,
      );

  factory EarnedTimeData.fromMap(Map<String, dynamic> map) {
    ActiveFreeSession? active;
    final activeMap = map['active_session'] as Map<String, dynamic>?;
    if (activeMap != null && activeMap['is_active'] == true) {
      final endsAt =
          (activeMap['ends_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      // If ends_at already passed, treat as inactive
      if (endsAt.isAfter(DateTime.now())) {
        active = ActiveFreeSession(
          startedAt: (activeMap['started_at'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          durationMins: activeMap['duration_mins'] as int? ?? 0,
          endsAt: endsAt,
        );
      }
    }
    return EarnedTimeData(
      balanceMins: (map['balance_mins'] as int? ?? 0).clamp(0, 180),
      lifetimeEarned: map['lifetime_earned'] as int? ?? 0,
      lifetimeSpent: map['lifetime_spent'] as int? ?? 0,
      activeSession: active,
    );
  }

  Map<String, dynamic> toMap() => {
        'balance_mins': balanceMins,
        'lifetime_earned': lifetimeEarned,
        'lifetime_spent': lifetimeSpent,
        'last_updated': FieldValue.serverTimestamp(),
        'active_session': {
          'is_active': false,
          'started_at': null,
          'duration_mins': 0,
          'ends_at': null,
        },
      };

  bool get hasFreeSession => activeSession != null;
  bool get hasBalance => balanceMins > 0;
}

class ActiveFreeSession {
  final DateTime startedAt;
  final int durationMins;
  final DateTime endsAt;

  const ActiveFreeSession({
    required this.startedAt,
    required this.durationMins,
    required this.endsAt,
  });

  int get remainingSeconds =>
      endsAt.difference(DateTime.now()).inSeconds.clamp(0, durationMins * 60);

  double get progress {
    final total = durationMins * 60;
    final elapsed = total - remainingSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
