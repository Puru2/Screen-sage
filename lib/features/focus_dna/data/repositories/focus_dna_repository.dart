import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/focus_dna.dart';

class FocusDNARepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<FocusDNA> computeDNA() async {
    debugPrint('🧬 Computing Focus DNA...');
    final user = _auth.currentUser!;

    // ── Fetch all sessions ever ─────────────────────────────
    final snap = await _db
        .collection('sessions')
        .where('user_id', isEqualTo: _uid)
        .orderBy('started_at', descending: false)
        .get();

    final sessions = snap.docs.map((d) => _RawSession.fromDoc(d)).toList();
    final finalized = sessions.where((s) => s.status != 'active').toList();
    final completed = finalized.where((s) => s.completed).toList();

    if (finalized.isEmpty) return _emptyDNA(user);

    // ── Streak data ──────────────────────────────────────────
    final streakSnap = await _db
        .collection('users')
        .doc(_uid)
        .collection('streak')
        .doc('data')
        .get();

    final currentStreak = streakSnap.data()?['current_streak'] as int? ?? 0;
    final longestStreak = streakSnap.data()?['longest_streak'] as int? ?? 0;

    // ── Completion rate ──────────────────────────────────────
    final completionRate = finalized.isNotEmpty
        ? (completed.length / finalized.length * 100).round()
        : 0;

    // ── Total hours ──────────────────────────────────────────
    final totalMins = completed.fold(0, (sum, s) => sum + s.completedMins);
    final totalHours = totalMins ~/ 60;

    // ── Avg session ──────────────────────────────────────────
    final avgSessionMins = completed.isNotEmpty
        ? completed.fold(0, (sum, s) => sum + s.completedMins) ~/
            completed.length
        : 0;

    // ── Peak hour analysis ───────────────────────────────────
    final hourBuckets = List.filled(24, 0);
    for (final s in completed) {
      hourBuckets[s.startedAt.hour]++;
    }
    int peakHour = 0;
    int peakCount = 0;
    for (int i = 0; i < 24; i++) {
      if (hourBuckets[i] > peakCount) {
        peakCount = hourBuckets[i];
        peakHour = i;
      }
    }
    final peakHourRange = _hourRange(peakHour);

    // ── Strongest day ────────────────────────────────────────
    final dayBuckets = List.filled(7, 0); // Mon=0 ... Sun=6
    for (final s in completed) {
      dayBuckets[s.startedAt.weekday - 1]++;
    }
    int bestDay = 0;
    int bestDayCount = 0;
    for (int i = 0; i < 7; i++) {
      if (dayBuckets[i] > bestDayCount) {
        bestDayCount = dayBuckets[i];
        bestDay = i;
      }
    }
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final strongestDay = dayNames[bestDay];

    // ── Tag breakdown ─────────────────────────────────────────
    final tagMap = <String, int>{};
    for (final s in completed) {
      if (s.tag.isNotEmpty) {
        tagMap[s.tag] = (tagMap[s.tag] ?? 0) + s.completedMins;
      }
    }

    // ── Focus Score ───────────────────────────────────────────
    final overrides = finalized.fold(0, (sum, s) => sum + s.overrides);

    final streakPoints = currentStreak * 10;
    final completionPoints = completionRate * 2;
    final totalHoursPoints = totalHours * 3;
    final avgSessionPoints = (avgSessionMins * 1.5).round();
    final consistencyBonus = currentStreak >= 7 ? 100 : currentStreak * 10;
    final overridePenalty = (overrides * 2).clamp(0, 200);

    final score = (streakPoints +
            completionPoints +
            totalHoursPoints +
            avgSessionPoints +
            consistencyBonus -
            overridePenalty)
        .clamp(0, 9999);

    // ── Archetype ─────────────────────────────────────────────
    final archetype = _computeArchetype(
      peakHour: peakHour,
      avgSessionMins: avgSessionMins,
      completionRate: completionRate,
      longestStreak: longestStreak,
      currentStreak: currentStreak,
      dayBuckets: dayBuckets,
      completed: completed,
    );

    // ── Percentile (local estimate) ───────────────────────────
    final percentile = _estimatePercentile(score);

    final dna = FocusDNA(
      focusScore: score,
      streakPoints: streakPoints,
      completionPoints: completionPoints,
      totalHoursPoints: totalHoursPoints,
      avgSessionPoints: avgSessionPoints,
      consistencyBonus: consistencyBonus,
      overridePenalty: overridePenalty,
      archetype: archetype.name,
      archetypeDescription: archetype.description,
      peakHourRange: peakHourRange,
      strongestDay: strongestDay,
      totalHoursAllTime: totalHours,
      longestStreak: longestStreak,
      currentStreak: currentStreak,
      completionRate: completionRate,
      avgSessionMins: avgSessionMins,
      totalSessions: finalized.length,
      topPercentile: percentile,
      tagBreakdown: tagMap,
      userId: _uid,
      displayName: user.displayName ?? 'Focuser',
      overrides: overrides,
    );

    debugPrint('🧬 DNA computed: score=$score archetype=${archetype.name}');
    return dna;
  }

  _Archetype _computeArchetype({
    required int peakHour,
    required int avgSessionMins,
    required int completionRate,
    required int longestStreak,
    required int currentStreak,
    required List<int> dayBuckets,
    required List<_RawSession> completed,
  }) {
    // Legend first
    if (currentStreak >= 30 || longestStreak >= 30) {
      return _Archetype(
        name: 'The Legend',
        description: 'Elite. You\'ve built focus into who you are.',
      );
    }

    // Comeback Kid — had a streak >= 7, reset, rebuilt
    if (longestStreak >= 7 &&
        currentStreak >= 3 &&
        currentStreak < longestStreak) {
      return _Archetype(
        name: 'Comeback Kid',
        description: 'You fell down and got back up. That\'s rare.',
      );
    }

    // Deep Diver
    if (avgSessionMins >= 45) {
      return _Archetype(
        name: 'Deep Diver',
        description: 'Long, unbroken focus. You go where most can\'t.',
      );
    }

    // Night Owl
    if (peakHour >= 20 || peakHour <= 2) {
      return _Archetype(
        name: 'Night Owl',
        description: 'The world quiets down. You come alive.',
      );
    }

    // Morning Sprinter
    if (peakHour >= 5 && peakHour <= 10 && avgSessionMins < 40) {
      return _Archetype(
        name: 'Morning Sprinter',
        description: 'Sharp, early, efficient. Done before others start.',
      );
    }

    // Weekend Warrior
    final weekendSessions = dayBuckets[5] + dayBuckets[6];
    final weekdaySessions = dayBuckets.take(5).fold(0, (a, b) => a + b);
    if (weekendSessions > weekdaySessions) {
      return _Archetype(
        name: 'Weekend Warrior',
        description: 'You batch your focus. Quiet weekends, big output.',
      );
    }

    // Consistent Grinder
    if (currentStreak >= 7 && completionRate >= 70) {
      return _Archetype(
        name: 'Consistent Grinder',
        description: 'Day after day, no excuses. Discipline personified.',
      );
    }

    // Marathon Runner
    if (avgSessionMins >= 35 && completionRate >= 65) {
      return _Archetype(
        name: 'Marathon Runner',
        description: 'Slow burn, high output. You play the long game.',
      );
    }

    // Default
    return _Archetype(
      name: 'Rising Focus',
      description: 'Every session builds the version of you that wins.',
    );
  }

  String _hourRange(int hour) {
    final end = (hour + 2) % 24;
    return '${_fmtHour(hour)} – ${_fmtHour(end)}';
  }

  String _fmtHour(int h) {
    if (h == 0) return '12am';
    if (h == 12) return '12pm';
    return h < 12 ? '${h}am' : '${h - 12}pm';
  }

  int _estimatePercentile(int score) {
    if (score >= 1500) return 1;
    if (score >= 1000) return 3;
    if (score >= 700) return 8;
    if (score >= 400) return 20;
    if (score >= 200) return 40;
    return 60;
  }

  FocusDNA _emptyDNA(User user) => FocusDNA(
      focusScore: 0,
      streakPoints: 0,
      avgSessionPoints: 0,
      completionPoints: 0,
      consistencyBonus: 0,
      overridePenalty: 0,
      totalHoursPoints: 0,
      archetype: 'New Focuser',
      archetypeDescription:
          'Your story is just beginning. First session changes everything.',
      peakHourRange: 'N/A',
      strongestDay: 'N/A',
      totalHoursAllTime: 0,
      longestStreak: 0,
      currentStreak: 0,
      completionRate: 0,
      avgSessionMins: 0,
      totalSessions: 0,
      topPercentile: 100,
      tagBreakdown: {},
      userId: user.uid,
      displayName: user.displayName ?? 'Focuser',
      overrides: 0);
}

class _RawSession {
  final DateTime startedAt;
  final int completedMins;
  final int overrides;
  final bool completed;
  final String tag;
  final String status;

  _RawSession(
      {required this.startedAt,
      required this.completedMins,
      required this.overrides,
      required this.completed,
      required this.tag,
      required this.status});

  factory _RawSession.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _RawSession(
      startedAt: (d['started_at'] as Timestamp).toDate(),
      completedMins: d['completed_mins'] as int? ?? 0,
      overrides: d['overrides'] as int? ?? 0,
      completed: d['completed'] as bool? ?? false,
      tag: d['tag'] as String? ?? '',
      status: d['status'] as String? ??
          ((d['completed'] == true) ? 'completed' : 'cancelled'),
    );
  }
}

class _Archetype {
  final String name;
  final String description;
  const _Archetype({required this.name, required this.description});
}
