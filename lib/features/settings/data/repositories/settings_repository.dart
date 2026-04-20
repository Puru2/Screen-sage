import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_settings.dart';

class SettingsRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference get _doc =>
      _db.collection('users').doc(_uid).collection('settings').doc('data');

  Future<UserSettings> getSettings() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      final defaults = const UserSettings();
      await _doc.set(defaults.toMap());
      return defaults;
    }
    return UserSettings.fromMap(snap.data() as Map<String, dynamic>);
  }

  Stream<UserSettings> watchSettings() =>
      _doc.snapshots().map((snap) => snap.exists
          ? UserSettings.fromMap(snap.data() as Map<String, dynamic>)
          : const UserSettings());

  Future<void> saveSettings(UserSettings settings) async {
    debugPrint('💾 Saving settings...');
    await _doc.set(settings.toMap(), SetOptions(merge: true));
    debugPrint('✅ Settings saved');
  }
}
