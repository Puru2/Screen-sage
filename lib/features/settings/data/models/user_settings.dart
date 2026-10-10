import 'package:cloud_firestore/cloud_firestore.dart';

import 'block_window.dart';

class UserSettings {
  final int dailyGoalMins; // default 120 (2 hours)
  final int defaultDurationMins; // default 25
  final bool soundEnabled;
  final String defaultFocusMode; // 'deep' | 'light' | 'custom'
  final bool deepFocusEnabled; // hides override button
  final List<BlockWindow> blockWindows; // daily scheduled downtime

  const UserSettings({
    this.dailyGoalMins = 120,
    this.defaultDurationMins = 25,
    this.soundEnabled = true,
    this.defaultFocusMode = 'deep',
    this.deepFocusEnabled = false,
    this.blockWindows = const [],
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        dailyGoalMins: map['daily_goal_mins'] as int? ?? 120,
        defaultDurationMins: map['default_duration_mins'] as int? ?? 25,
        soundEnabled: map['sound_enabled'] as bool? ?? true,
        defaultFocusMode: map['default_focus_mode'] as String? ?? 'deep',
        deepFocusEnabled: map['deep_focus_enabled'] as bool? ?? false,
        blockWindows: (map['block_windows'] as List? ?? const [])
            .whereType<Map>()
            .map((w) => BlockWindow.fromMap(Map<String, dynamic>.from(w)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'daily_goal_mins': dailyGoalMins,
        'default_duration_mins': defaultDurationMins,
        'sound_enabled': soundEnabled,
        'default_focus_mode': defaultFocusMode,
        'deep_focus_enabled': deepFocusEnabled,
        'block_windows': blockWindows.map((w) => w.toMap()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  UserSettings copyWith({
    int? dailyGoalMins,
    int? defaultDurationMins,
    bool? soundEnabled,
    String? defaultFocusMode,
    bool? deepFocusEnabled,
    List<BlockWindow>? blockWindows,
  }) =>
      UserSettings(
        dailyGoalMins: dailyGoalMins ?? this.dailyGoalMins,
        defaultDurationMins: defaultDurationMins ?? this.defaultDurationMins,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        defaultFocusMode: defaultFocusMode ?? this.defaultFocusMode,
        deepFocusEnabled: deepFocusEnabled ?? this.deepFocusEnabled,
        blockWindows: blockWindows ?? this.blockWindows,
      );
}

enum FocusModeType { deep, light, custom }

class FocusMode {
  final FocusModeType type;
  final String label;
  final String emoji;
  final String description;
  final int suggestedDuration;
  final bool hideOverride; // Deep mode hides the override button on shield

  const FocusMode({
    required this.type,
    required this.label,
    required this.emoji,
    required this.description,
    required this.suggestedDuration,
    this.hideOverride = false,
  });

  static const deep = FocusMode(
    type: FocusModeType.deep,
    label: 'Deep Work',
    emoji: '🧠',
    description: 'No distractions. No mercy.',
    suggestedDuration: 50,
    hideOverride: true,
  );

  static const light = FocusMode(
    type: FocusModeType.light,
    label: 'Light Focus',
    emoji: '🌿',
    description: 'Focused but flexible.',
    suggestedDuration: 25,
    hideOverride: false,
  );

  static const custom = FocusMode(
    type: FocusModeType.custom,
    label: 'Custom',
    emoji: '⚙️',
    description: 'Your rules.',
    suggestedDuration: 25,
    hideOverride: false,
  );

  static const all = [deep, light, custom];

  static FocusMode fromType(FocusModeType type) =>
      all.firstWhere((m) => m.type == type);

  static FocusMode fromString(String s) => switch (s) {
        'deep' => deep,
        'light' => light,
        _ => custom,
      };

  String get typeString => switch (type) {
        FocusModeType.deep => 'deep',
        FocusModeType.light => 'light',
        FocusModeType.custom => 'custom',
      };
}
