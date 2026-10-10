/// A daily recurring app-block window ("downtime").
///
/// Persisted inside `UserSettings` (Firestore) and mirrored to the iOS
/// App Group so the DeviceActivity extension can keep shields aligned
/// even when the app isn't running.
class BlockWindow {
  final String id;
  final int startMinutes; // minutes since midnight (0–1439)
  final int endMinutes; // minutes since midnight (0–1439)
  final bool enabled;

  const BlockWindow({
    required this.id,
    required this.startMinutes,
    required this.endMinutes,
    this.enabled = true,
  });

  bool get isFullDay => startMinutes == 0 && endMinutes >= 1439;

  factory BlockWindow.fromMap(Map<String, dynamic> map) => BlockWindow(
        id: map['id'] as String? ?? '',
        startMinutes: map['start_minutes'] as int? ?? 0,
        endMinutes: map['end_minutes'] as int? ?? 0,
        enabled: map['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'enabled': enabled,
      };

  /// Payload for the iOS MethodChannel — keys must match AppDelegate parsing.
  Map<String, dynamic> toNativeMap() => {
        'id': id,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'enabled': enabled,
      };

  BlockWindow copyWith({
    int? startMinutes,
    int? endMinutes,
    bool? enabled,
  }) =>
      BlockWindow(
        id: id,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        enabled: enabled ?? this.enabled,
      );

  /// e.g. "9:00 AM – 5:00 PM" or "All day"
  String get label {
    if (isFullDay) return 'All day';
    return '${_fmt(startMinutes)} – ${_fmt(endMinutes)}';
  }

  /// Compact variant for tight spaces: "9 AM – 5 PM".
  String get shortLabel {
    if (isFullDay) return 'All day';
    return '${_fmtShort(startMinutes)} – ${_fmtShort(endMinutes)}';
  }

  static String _fmt(int mins) {
    final h24 = (mins ~/ 60) % 24;
    final m = mins % 60;
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  static String _fmtShort(int mins) {
    final h24 = (mins ~/ 60) % 24;
    final m = mins % 60;
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return m == 0
        ? '$h12 $suffix'
        : '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  @override
  bool operator ==(Object other) =>
      other is BlockWindow &&
      other.id == id &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, startMinutes, endMinutes, enabled);
}
