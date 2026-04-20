import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screensage/core/widgets/premium_gate_widget.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../analytics/data/repositories/analytics_repository.dart';
import '../../data/models/focus_dna.dart';
import '../../data/repositories/focus_dna_repository.dart';
import '../bloc/focus_dna_bloc.dart';
import '../widgets/focus_constellation_widget.dart';

class FocusDNAScreen extends StatelessWidget {
  const FocusDNAScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          FocusDNABloc(FocusDNARepository())..add(FocusDNALoadRequested()),
      child: const _FocusDNAView(),
    );
  }
}

class _FocusDNAView extends StatefulWidget {
  const _FocusDNAView();

  @override
  State<_FocusDNAView> createState() => _FocusDNAViewState();
}

class _FocusDNAViewState extends State<_FocusDNAView> {
  final _cardKey = GlobalKey();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScreenSageColors.background,
      body: BlocBuilder<FocusDNABloc, FocusDNAState>(
        builder: (context, state) {
          return switch (state) {
            FocusDNALoading() => const Center(
                child: CircularProgressIndicator(
                  color: ScreenSageColors.accent,
                  strokeWidth: 2,
                ),
              ),
            FocusDNAError(:final message) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: ScreenSageColors.danger, size: 40),
                    const SizedBox(height: 12),
                    Text(message,
                        style: ScreenSageTextStyles.bodyMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context
                          .read<FocusDNABloc>()
                          .add(FocusDNALoadRequested()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            FocusDNALoaded(:final dna) => _buildLoaded(context, dna),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, FocusDNA dna) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Focus DNA',
                                style: ScreenSageTextStyles.headlineLarge),
                            Text(
                              'Your personal focus fingerprint',
                              style: ScreenSageTextStyles.bodyMedium.copyWith(
                                color: ScreenSageColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Refresh
                      IconButton(
                        onPressed: () => context
                            .read<FocusDNABloc>()
                            .add(FocusDNALoadRequested()),
                        icon: const Icon(Icons.refresh_rounded,
                            color: ScreenSageColors.textSecondary),
                      ),
                    ],
                  ).animate().fadeIn(delay: 50.ms),
                ),

                const SizedBox(height: 28),

                // ── Shareable Card ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: PremiumGateWidget(
                    featureName: 'Focus DNA',
                    style: GateStyle.teaser,
                    teaserEmoji: '🧬',
                    teaserDescription:
                        'Discover your unique focus archetype. Builds over time with every session.',
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: _ShareableCard(dna: dna),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                  ),
                ),

                const SizedBox(height: 16),

                // Share button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSharing ? null : () => _shareCard(context, dna),
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(
                        _isSharing ? 'Preparing...' : 'Share My Focus DNA'),
                  ).animate().fadeIn(delay: 200.ms),
                ),

                const SizedBox(height: 32),

                // ── Stats Grid ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child:
                      Text('Breakdown', style: ScreenSageTextStyles.labelMedium)
                          .animate()
                          .fadeIn(delay: 250.ms),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _StatsGrid(dna: dna).animate().fadeIn(delay: 300.ms),
                ),

                const SizedBox(height: 24),

                // ── Tag Breakdown ──────────────────────────────
                if (dna.tagBreakdown.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // Keeps your text aligned to the left
                      children: [
                        Text('Focus by Tag',
                                style: ScreenSageTextStyles.labelMedium)
                            .animate()
                            .fadeIn(delay: 350.ms),
                        const SizedBox(height: 12),
                        PremiumGateWidget(
                          featureName: 'Tag Breakdown',
                          style: GateStyle.banner,
                          child: _TagBreakdown(tagBreakdown: dna.tagBreakdown),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                // ── Score explanation ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child:
                      _ScoreExplainer(dna: dna).animate().fadeIn(delay: 450.ms),
                ),

                const SizedBox(height: 40),

                FutureBuilder<AnalyticsSummary>(
                  future: AnalyticsRepository()
                      .getSummary(range: AnalyticsRange.month),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    return PremiumGateWidget(
                      featureName: 'Focus Constellation',
                      style: GateStyle.overlay,
                      child: FocusConstellation(
                        sessions: snap.data!.recentSessions,
                      ),
                    ).animate().fadeIn(delay: 300.ms);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareCard(BuildContext context, FocusDNA dna) async {
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/focus_dna.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'My Focus DNA on ScreenSage — ${dna.archetype} | Score: ${dna.focusScore} 🧠\nscreensage.app',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: ScreenSageColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

// ── Shareable Card ─────────────────────────────────────────────────
class _ShareableCard extends StatelessWidget {
  const _ShareableCard({required this.dna});
  final FocusDNA dna;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A1628),
            ScreenSageColors.accent.withOpacity(0.15),
            const Color(0xFF0A0F1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ScreenSageColors.accent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScreenSageColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: ScreenSageColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dna.displayName}\'s Focus DNA',
                      style: ScreenSageTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ScreenSage',
                      style: ScreenSageTextStyles.bodySmall.copyWith(
                        color: ScreenSageColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              // Score badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ScreenSageColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ScreenSageColors.accent.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '${dna.focusScore}',
                  style: ScreenSageTextStyles.titleMedium.copyWith(
                    color: ScreenSageColors.accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Archetype
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dna.archetype,
                  style: ScreenSageTextStyles.headlineMedium.copyWith(
                    color: ScreenSageColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dna.archetypeDescription,
                  style: ScreenSageTextStyles.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _CardStat(
                icon: Icons.local_fire_department_rounded,
                label: 'Best Streak',
                value: '${dna.longestStreak}d',
                color: ScreenSageColors.amber,
              ),
              const SizedBox(width: 10),
              _CardStat(
                icon: Icons.schedule_rounded,
                label: 'Total Focus',
                value: '${dna.totalHoursAllTime}h',
                color: ScreenSageColors.accent,
              ),
              const SizedBox(width: 10),
              _CardStat(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completion',
                value: '${dna.completionRate}%',
                color: ScreenSageColors.violet,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Peak info row
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Peak: ${dna.peakHourRange}',
                style: ScreenSageTextStyles.bodySmall.copyWith(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Best day: ${dna.strongestDay}',
                style: ScreenSageTextStyles.bodySmall.copyWith(
                  color: Colors.white54,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Percentile
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Top ${dna.topPercentile}% of ScreenSage users',
                style: ScreenSageTextStyles.bodySmall.copyWith(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: ScreenSageTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                )),
            Text(label,
                style: ScreenSageTextStyles.bodySmall.copyWith(
                  color: Colors.white38,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.dna});
  final FocusDNA dna;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _GridStat(
        icon: Icons.psychology_rounded,
        label: 'Focus Score',
        value: '${dna.focusScore}',
        sub: dna.scoreTier,
        color: ScreenSageColors.accent,
      ),
      _GridStat(
        icon: Icons.local_fire_department_rounded,
        label: 'Current Streak',
        value: '${dna.currentStreak}d',
        sub: 'Best: ${dna.longestStreak}d',
        color: ScreenSageColors.amber,
      ),
      _GridStat(
        icon: Icons.timer_rounded,
        label: 'Avg Session',
        value: '${dna.avgSessionMins}m',
        sub: '${dna.totalSessions} sessions',
        color: ScreenSageColors.violet,
      ),
      _GridStat(
        icon: Icons.trending_up_rounded,
        label: 'Completion Rate',
        value: '${dna.completionRate}%',
        sub: 'All time',
        color: ScreenSageColors.accent,
      ),
      _GridStat(
        icon: Icons.wb_sunny_outlined,
        label: 'Peak Time',
        value: dna.peakHourRange,
        sub: 'Most productive',
        color: ScreenSageColors.amber,
      ),
      _GridStat(
        icon: Icons.calendar_today_rounded,
        label: 'Best Day',
        value: dna.strongestDay.substring(0, 3),
        sub: dna.strongestDay,
        color: ScreenSageColors.violet,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _GridStatCard(stat: stats[i]),
    );
  }
}

class _GridStat {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _GridStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
}

class _GridStatCard extends StatelessWidget {
  const _GridStatCard({required this.stat});
  final _GridStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(stat.icon, size: 18, color: stat.color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stat.value,
                  style: ScreenSageTextStyles.titleLarge
                      .copyWith(color: ScreenSageColors.textPrimary)),
              Text(stat.label, style: ScreenSageTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tag Breakdown ─────────────────────────────────────────────────
class _TagBreakdown extends StatelessWidget {
  const _TagBreakdown({required this.tagBreakdown});
  final Map<String, int> tagBreakdown;

  @override
  Widget build(BuildContext context) {
    final total = tagBreakdown.values.fold(0, (a, b) => a + b);
    final sorted = tagBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      ScreenSageColors.accent,
      ScreenSageColors.violet,
      ScreenSageColors.amber,
      ScreenSageColors.accent.withOpacity(0.6),
      ScreenSageColors.violet.withOpacity(0.6),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final tag = entry.value.key;
          final mins = entry.value.value;
          final ratio = total > 0 ? mins / total : 0.0;
          final color = colors[i % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tag, style: ScreenSageTextStyles.bodyMedium),
                    ),
                    Text(
                      _fmt(mins),
                      style: ScreenSageTextStyles.bodyMedium.copyWith(
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: ScreenSageTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: ScreenSageColors.border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmt(int mins) {
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h ${mins % 60}m';
  }
}

// ── Score Explainer ───────────────────────────────────────────────
class _ScoreExplainer extends StatelessWidget {
  const _ScoreExplainer({required this.dna});
  final FocusDNA dna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: ScreenSageColors.textSecondary),
              const SizedBox(width: 8),
              Text('How Focus Score works',
                  style: ScreenSageTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          _ScoreRow(
              label: 'Streak',
              value: dna.currentStreak * 10,
              color: ScreenSageColors.amber),
          _ScoreRow(
              label: 'Completion rate',
              value: dna.completionRate * 2,
              color: ScreenSageColors.violet),
          _ScoreRow(
              label: 'Total hours focused',
              value: dna.totalHoursAllTime * 3,
              color: ScreenSageColors.accent),
          _ScoreRow(
              label: 'Avg session quality',
              value: (dna.avgSessionMins * 1.5).round(),
              color: ScreenSageColors.accent),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: ScreenSageTextStyles.bodyMedium)),
          Text('+$value pts',
              style: ScreenSageTextStyles.bodyMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
