import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ── Range enum ────────────────────────────────────────────────────
enum AnalyticsRange { today, week, month }

extension AnalyticsRangeX on AnalyticsRange {
  String get label => switch (this) {
        AnalyticsRange.today => 'Today',
        AnalyticsRange.week => 'This Week',
        AnalyticsRange.month => 'This Month',
      };
}

class AnalyticsRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  Future<int> getTodayFocusMinutes() async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    final todayStart = Timestamp.fromDate(DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ));
    final snapshot = await _db
        .collection('sessions')
        .where('user_id', isEqualTo: _uid)
        .where('completed', isEqualTo: true)
        .where('started_at', isGreaterThanOrEqualTo: todayStart)
        .get();
    return snapshot.docs.fold<int>(
        0, (sum, doc) => sum + (doc.data()['completed_mins'] as int? ?? 0));
  }

  Future<AnalyticsSummary> getSummary({
    AnalyticsRange range = AnalyticsRange.week,
  }) async {
    debugPrint('📊 Fetching analytics summary for range: ${range.label}');

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    // Always fetch full month — filter in memory for range
    final snapshot = await _db
        .collection('sessions')
        .where('user_id', isEqualTo: _uid)
        .where('started_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .orderBy('started_at', descending: true)
        .get();

    final allSessions = snapshot.docs.map((doc) {
      final d = doc.data();
      return AnalyticsSession(
        id: doc.id,
        startedAt: (d['started_at'] as Timestamp).toDate(),
        durationMins: d['duration_mins'] as int? ?? 0,
        completedMins: d['completed_mins'] as int? ?? 0,
        overrides: d['overrides'] as int? ?? 0,
        completed: d['completed'] as bool? ?? false,
        tag: d['tag'] as String? ?? '',
        intention: d['intention'] as String? ?? '',
        focusMode: d['focus_mode'] as String? ?? 'deep',
      );
    }).toList();

    // Range-filtered sessions
    final rangeStart = switch (range) {
      AnalyticsRange.today => todayStart,
      AnalyticsRange.week => weekStart,
      AnalyticsRange.month => monthStart,
    };
    final rangeSessions =
        allSessions.where((s) => s.startedAt.isAfter(rangeStart)).toList();

    // Core stats
    final todayMins = allSessions
        .where((s) => s.completed && s.startedAt.isAfter(todayStart))
        .fold(0, (sum, s) => sum + s.completedMins);
    final weekMins = allSessions
        .where((s) => s.completed && s.startedAt.isAfter(weekStart))
        .fold(0, (sum, s) => sum + s.completedMins);
    final monthMins = allSessions
        .where((s) => s.completed)
        .fold(0, (sum, s) => sum + s.completedMins);

    final totalSessions = rangeSessions.length;
    final completedCount = rangeSessions.where((s) => s.completed).length;
    final completionRate =
        totalSessions > 0 ? (completedCount / totalSessions * 100).round() : 0;
    final weekOverrides = rangeSessions.fold(0, (sum, s) => sum + s.overrides);

    // Daily breakdown — adapts to range
    final chartDays = switch (range) {
      AnalyticsRange.today => 1,
      AnalyticsRange.week => 7,
      AnalyticsRange.month => 30,
    };
    final dailyMins = <String, int>{};
    for (int i = chartDays - 1; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      final label = range == AnalyticsRange.month
          ? '${day.day}' // day number for month view
          : _dayLabel(day);
      dailyMins[label] = 0;
    }
    for (final s in rangeSessions) {
      if (!s.completed) continue;
      final label = range == AnalyticsRange.month
          ? '${s.startedAt.day}'
          : _dayLabel(s.startedAt);
      if (dailyMins.containsKey(label)) {
        dailyMins[label] = (dailyMins[label] ?? 0) + s.completedMins;
      }
    }

    // Best day
    int bestDayMins = 0;
    String bestDayLabel = '-';
    dailyMins.forEach((label, mins) {
      if (mins > bestDayMins) {
        bestDayMins = mins;
        bestDayLabel = label;
      }
    });

    // Avg session
    final completedSessions = rangeSessions.where((s) => s.completed).toList();
    final avgSessionMins = completedSessions.isNotEmpty
        ? completedSessions.fold(0, (sum, s) => sum + s.completedMins) ~/
            completedSessions.length
        : 0;

    // Tag breakdown
    final tagMap = <String, int>{};
    for (final s in rangeSessions) {
      if (!s.completed || s.tag.isEmpty) continue;
      tagMap[s.tag] = (tagMap[s.tag] ?? 0) + s.completedMins;
    }
    final tagBreakdown = tagMap.entries
        .map((e) => TagStat(tag: e.key, mins: e.value))
        .toList()
      ..sort((a, b) => b.mins.compareTo(a.mins));

    // Focus mode breakdown
    final modeMap = <String, int>{};
    for (final s in rangeSessions) {
      if (!s.completed) continue;
      final mode = s.focusMode.isEmpty ? 'deep' : s.focusMode;
      modeMap[mode] = (modeMap[mode] ?? 0) + s.completedMins;
    }

    debugPrint(
        '📊 Done: today=${todayMins}m week=${weekMins}m month=${monthMins}m tags=${tagBreakdown.length}');

    return AnalyticsSummary(
      todayMins: todayMins,
      weekMins: weekMins,
      monthMins: monthMins,
      rangeMins: switch (range) {
        AnalyticsRange.today => todayMins,
        AnalyticsRange.week => weekMins,
        AnalyticsRange.month => monthMins,
      },
      completionRate: completionRate,
      totalSessions: totalSessions,
      completedSessions: completedCount,
      weekOverrides: weekOverrides,
      dailyMins: dailyMins,
      bestDayLabel: bestDayLabel,
      bestDayMins: bestDayMins,
      avgSessionMins: avgSessionMins,
      recentSessions: rangeSessions.take(10).toList(),
      tagBreakdown: tagBreakdown,
      focusModeBreakdown: modeMap,
      activeRange: range,
    );
  }

  String _dayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

// ── Models ────────────────────────────────────────────────────────

class AnalyticsSession {
  final String id;
  final DateTime startedAt;
  final int durationMins;
  final int completedMins;
  final int overrides;
  final bool completed;
  final String tag;
  final String intention;
  final String focusMode;

  const AnalyticsSession({
    required this.id,
    required this.startedAt,
    required this.durationMins,
    required this.completedMins,
    required this.overrides,
    required this.completed,
    required this.tag,
    required this.intention,
    required this.focusMode,
  });
}

class TagStat {
  final String tag;
  final int mins;
  const TagStat({required this.tag, required this.mins});
}

class AnalyticsSummary {
  final int todayMins;
  final int weekMins;
  final int monthMins;
  final int rangeMins; // mins for currently selected range
  final int completionRate;
  final int totalSessions;
  final int completedSessions;
  final int weekOverrides;
  final Map<String, int> dailyMins;
  final String bestDayLabel;
  final int bestDayMins;
  final int avgSessionMins;
  final List<AnalyticsSession> recentSessions;
  final List<TagStat> tagBreakdown;
  final Map<String, int> focusModeBreakdown;
  final AnalyticsRange activeRange;

  const AnalyticsSummary({
    required this.todayMins,
    required this.weekMins,
    required this.monthMins,
    required this.rangeMins,
    required this.completionRate,
    required this.totalSessions,
    required this.completedSessions,
    required this.weekOverrides,
    required this.dailyMins,
    required this.bestDayLabel,
    required this.bestDayMins,
    required this.avgSessionMins,
    required this.recentSessions,
    required this.tagBreakdown,
    required this.focusModeBreakdown,
    required this.activeRange,
  });

  factory AnalyticsSummary.empty() => const AnalyticsSummary(
        todayMins: 0,
        weekMins: 0,
        monthMins: 0,
        rangeMins: 0,
        completionRate: 0,
        totalSessions: 0,
        completedSessions: 0,
        weekOverrides: 0,
        dailyMins: {},
        bestDayLabel: '-',
        bestDayMins: 0,
        avgSessionMins: 0,
        recentSessions: [],
        tagBreakdown: [],
        focusModeBreakdown: {},
        activeRange: AnalyticsRange.week,
      );
}
