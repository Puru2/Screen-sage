import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/screen_time_service.dart';

class SessionRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  Future<String> createSession({
    required int durationMins,
    String intention = '',
    String focusMode = 'deep',
    String tag = '',
  }) async {
    final appCount = await ScreenTimeService.getSelectedAppCount();
    final docRef = await _db.collection('sessions').add({
      'user_id': _uid,
      'duration_mins': durationMins,
      'completed_mins': 0,
      'overrides': 0,
      'completed': false,
      'intention': intention,
      'focus_mode': focusMode,
      'tag': tag,
      'apps_blocked': appCount,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'started_at': FieldValue.serverTimestamp(),
      'ended_at': null,
    });
    return docRef.id;
  }

  Future<void> completeSession({
    required String sessionId,
    required int completedMins,
    required int overrides,
    required bool completed,
  }) async {
    debugPrint('💾 Firestore: completing session $sessionId');
    debugPrint(
        '   completedMins=$completedMins overrides=$overrides completed=$completed');

    await _db.collection('sessions').doc(sessionId).update({
      'completed_mins': completedMins,
      'overrides': overrides,
      'completed': completed,
      'ended_at': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Firestore: session $sessionId saved');
  }

  // For Analytics Screen
  Future<List<Map<String, dynamic>>> getRecentSessions({
    int limit = 30,
  }) async {
    debugPrint('📊 Firestore: fetching last $limit sessions');
    final snapshot = await _db
        .collection('sessions')
        .where('user_id', isEqualTo: _uid)
        .orderBy('started_at', descending: true)
        .limit(limit)
        .get();

    final sessions = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      // Convert Timestamp to ISO string for consistency
      if (data['started_at'] is Timestamp) {
        data['started_at'] =
            (data['started_at'] as Timestamp).toDate().toIso8601String();
      }
      if (data['ended_at'] is Timestamp) {
        data['ended_at'] =
            (data['ended_at'] as Timestamp).toDate().toIso8601String();
      }
      return data;
    }).toList();

    debugPrint('📊 Firestore: fetched ${sessions.length} sessions');
    return sessions;
  }

  // Weekly stats for Analytics
  Future<Map<String, dynamic>> getWeeklyStats() async {
    final weekAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    final snapshot = await _db
        .collection('sessions')
        .where('user_id', isEqualTo: _uid)
        .where('started_at', isGreaterThanOrEqualTo: weekAgo)
        .get();

    int totalMins = 0;
    int completedCount = 0;
    int totalCount = snapshot.docs.length;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['completed'] == true) {
        totalMins += (data['completed_mins'] as int? ?? 0);
        completedCount++;
      }
    }

    return {
      'total_focus_mins': totalMins,
      'completed_sessions': completedCount,
      'total_sessions': totalCount,
      'completion_rate':
          totalCount > 0 ? (completedCount / totalCount * 100).round() : 0,
    };
  }

  // Today's sessions for the home screen
  Future<int> getTodayFocusMinutes() async {
    final todayStart = Timestamp.fromDate(
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );

    final snapshot = await _db
        .collection('sessions')
        .where('user_id', isEqualTo: _uid)
        .where('completed', isEqualTo: true)
        .where('started_at', isGreaterThanOrEqualTo: todayStart)
        .get();

    return snapshot.docs.fold<int>(
      0,
      (sum, doc) => sum + (doc.data()['completed_mins'] as int? ?? 0),
    );
  }
}
