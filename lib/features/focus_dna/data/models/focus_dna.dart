class FocusDNA {
  final int focusScore;
  final String archetype;
  final String archetypeDescription;
  final String peakHourRange;
  final String strongestDay;
  final int totalHoursAllTime;
  final int longestStreak;
  final int currentStreak;
  final int completionRate;
  final int avgSessionMins;
  final int totalSessions;
  final int topPercentile; // e.g. 8 = "top 8%"
  final Map<String, int> tagBreakdown;
  final String userId;
  final String displayName;

  const FocusDNA({
    required this.focusScore,
    required this.archetype,
    required this.archetypeDescription,
    required this.peakHourRange,
    required this.strongestDay,
    required this.totalHoursAllTime,
    required this.longestStreak,
    required this.currentStreak,
    required this.completionRate,
    required this.avgSessionMins,
    required this.totalSessions,
    required this.topPercentile,
    required this.tagBreakdown,
    required this.userId,
    required this.displayName,
  });

  // Score tier
  String get scoreTier {
    if (focusScore >= 1500) return 'Legendary';
    if (focusScore >= 1000) return 'Elite';
    if (focusScore >= 600) return 'Advanced';
    if (focusScore >= 300) return 'Building';
    if (focusScore >= 100) return 'Starting';
    return 'New';
  }

  String get scoreTierEmoji {
    if (focusScore >= 1500) return '👑';
    if (focusScore >= 1000) return '💎';
    if (focusScore >= 600) return '🚀';
    if (focusScore >= 300) return '🔥';
    if (focusScore >= 100) return '⚡';
    return '🌱';
  }
}
