class OnboardingPage {
  final String emoji;
  final String headline;
  final String subheadline;
  final String body;

  const OnboardingPage({
    required this.emoji,
    required this.headline,
    required this.subheadline,
    required this.body,
  });
}

class OnboardingData {
  static const pages = [
    OnboardingPage(
      emoji: '🧠',
      headline: 'Your phone\nis watching you.',
      subheadline: 'Average person unlocks their phone 96 times a day.',
      body:
          'ScreenSage helps you take back your attention — one session at a time.',
    ),
    OnboardingPage(
      emoji: '🌿',
      headline: 'Focus earns\nrewards.',
      subheadline: 'Not punishment. Empowerment.',
      body:
          'Complete sessions, walk, read — earn back time. Your focus builds real momentum.',
    ),
    OnboardingPage(
      emoji: '🔥',
      headline: 'Your streak\nstarts today.',
      subheadline: '7 days free. Then \$4.99/month.',
      body:
          'No dark patterns. If ScreenSage doesn\'t change your habits in a week, you owe us nothing.',
    ),
  ];
}
