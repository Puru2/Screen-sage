import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/premium_gate_widget.dart';
import '../../data/repositories/analytics_repository.dart';
import '../bloc/analytics_bloc.dart';
import '../widgets/focus_bar_chart.dart';
import '../widgets/session_history_tile.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AnalyticsBloc(AnalyticsRepository())..add(AnalyticsLoadRequested()),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScreenSageColors.background,
      body: SafeArea(
        child: BlocBuilder<AnalyticsBloc, AnalyticsState>(
          builder: (context, state) {
            return RefreshIndicator(
              color: ScreenSageColors.accent,
              backgroundColor: ScreenSageColors.surface,
              onRefresh: () async {
                context.read<AnalyticsBloc>().add(AnalyticsRefreshRequested());
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Insights',
                              style: ScreenSageTextStyles.headlineLarge),
                          if (state is AnalyticsLoaded)
                            GestureDetector(
                              onTap: () => context
                                  .read<AnalyticsBloc>()
                                  .add(AnalyticsRefreshRequested()),
                              child: const Icon(Icons.refresh_rounded,
                                  color: ScreenSageColors.textTertiary,
                                  size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Range Selector ───────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: state is AnalyticsLoaded
                          ? _RangeSelector(
                              selected: state.summary.activeRange,
                              onChanged: (r) {
                                HapticFeedback.selectionClick();
                                context
                                    .read<AnalyticsBloc>()
                                    .add(AnalyticsRangeChanged(r));
                              },
                            )
                          : const _RangeSelector(
                              selected: AnalyticsRange.week,
                              onChanged: null,
                            ),
                    ),
                  ),

                  if (state is AnalyticsLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: ScreenSageColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),

                  if (state is AnalyticsError)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: ScreenSageColors.danger, size: 40),
                            const SizedBox(height: 12),
                            Text(state.message,
                                style: ScreenSageTextStyles.bodyMedium,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<AnalyticsBloc>()
                                  .add(AnalyticsLoadRequested()),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (state is AnalyticsLoaded) ...[
                    if (state.summary.activeRange == AnalyticsRange.month)
                      SliverToBoxAdapter(
                        child: PremiumGateWidget(
                          featureName: 'Monthly Analytics',
                          style: GateStyle.overlay,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch, // ← KEY
                            children: _buildContentWidgets(state.summary),
                          ),
                        ),
                      )
                    else
                      _buildContent(state.summary),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(AnalyticsSummary s) {
    return SliverList(
      delegate: SliverChildListDelegate(_buildContentWidgets(s)),
    );
  }

  List<Widget> _buildContentWidgets(AnalyticsSummary s) {
    return [
      const SizedBox(height: 20),
      _HeroStatCard(summary: s).animate().fadeIn(delay: 80.ms),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Completion',
                value: '${s.completionRate}%',
                sub: '${s.completedSessions}/${s.totalSessions} sessions',
                color: s.completionRate >= 80
                    ? ScreenSageColors.accent
                    : s.completionRate >= 50
                        ? ScreenSageColors.amber
                        : ScreenSageColors.danger,
              ).animate().fadeIn(delay: 120.ms),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Avg Session',
                value: _formatMins(s.avgSessionMins),
                sub: 'per session',
                color: ScreenSageColors.violet,
              ).animate().fadeIn(delay: 150.ms),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Overrides',
                value: '${s.weekOverrides}',
                sub: s.activeRange.label.toLowerCase(),
                color: s.weekOverrides == 0
                    ? ScreenSageColors.accent
                    : ScreenSageColors.danger,
              ).animate().fadeIn(delay: 180.ms),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ScreenSageColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ScreenSageColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daily Focus', style: ScreenSageTextStyles.titleMedium),
                  if (s.bestDayMins > 0)
                    Text(
                      'Best: ${s.bestDayLabel} · ${_formatMins(s.bestDayMins)}',
                      style: ScreenSageTextStyles.labelSmall
                          .copyWith(color: ScreenSageColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FocusBarChart(
                dailyMins: s.dailyMins,
                // Pass range so chart knows how many bars to show
                // range: s.activeRange,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 220.ms),
      ),
      const SizedBox(height: 20),
      if (s.tagBreakdown.isNotEmpty) ...[
        PremiumGateWidget(
          featureName: 'Tag Breakdown',
          style: GateStyle.banner,
          child: _TagBreakdown(tags: s.tagBreakdown, totalMins: s.rangeMins),
        ).animate().fadeIn(delay: 260.ms),
        const SizedBox(height: 20),
      ],
      if (s.focusModeBreakdown.isNotEmpty) ...[
        _FocusModeBreakdown(modes: s.focusModeBreakdown)
            .animate()
            .fadeIn(delay: 290.ms),
        const SizedBox(height: 20),
      ],
      if (s.recentSessions.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child:
              Text('Recent Sessions', style: ScreenSageTextStyles.titleMedium),
        ).animate().fadeIn(delay: 320.ms),
        ...s.recentSessions.asMap().entries.map((entry) {
          return SessionHistoryTile(
            durationMins: entry.value.durationMins,
            completedMins: entry.value.completedMins,
            overrides: entry.value.overrides,
            completed: entry.value.completed,
            startedAt: entry.value.startedAt,
          ).animate().fadeIn(
                delay: Duration(milliseconds: 340 + entry.key * 30),
              );
        }),
        const SizedBox(height: 40),
      ] else ...[
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              const Text('🌱', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('No sessions yet', style: ScreenSageTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Complete a session to see your insights.',
                style: ScreenSageTextStyles.bodyMedium,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 48),
      ],
    ];
  }

  static String _formatMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ── Range Selector ────────────────────────────────────────────────
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final AnalyticsRange selected;
  final ValueChanged<AnalyticsRange>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Row(
        children: AnalyticsRange.values.map((range) {
          final isSelected = range == selected;
          return Expanded(
            child: GestureDetector(
              onTap: onChanged != null ? () => onChanged!(range) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color:
                      isSelected ? ScreenSageColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    range.label,
                    style: ScreenSageTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? const Color(0xFF001A0F)
                          : ScreenSageColors.textTertiary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Hero Stat Card ────────────────────────────────────────────────
class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({required this.summary});
  final AnalyticsSummary summary;

  static String _formatMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final label = summary.activeRange.label;
    final mins = summary.rangeMins;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ScreenSageColors.accent.withOpacity(0.15),
              ScreenSageColors.violet.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ScreenSageColors.accent.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ScreenSageTextStyles.labelMedium.copyWith(
                      color: ScreenSageColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMins(mins),
                    style: ScreenSageTextStyles.displayMedium.copyWith(
                      color: ScreenSageColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'focused',
                    style: ScreenSageTextStyles.bodyMedium.copyWith(
                      color: ScreenSageColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Mini today/week/month pills if range != today
            if (summary.activeRange != AnalyticsRange.today)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (summary.activeRange == AnalyticsRange.month) ...[
                    _MiniPill(
                        label: 'Today', value: _formatMins(summary.todayMins)),
                    const SizedBox(height: 6),
                    _MiniPill(
                        label: 'Week', value: _formatMins(summary.weekMins)),
                  ] else ...[
                    _MiniPill(
                        label: 'Today', value: _formatMins(summary.todayMins)),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: ScreenSageTextStyles.bodySmall
                  .copyWith(color: ScreenSageColors.textTertiary),
            ),
            TextSpan(
              text: value,
              style: ScreenSageTextStyles.labelSmall.copyWith(
                color: ScreenSageColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag Breakdown ─────────────────────────────────────────────────
class _TagBreakdown extends StatelessWidget {
  const _TagBreakdown({required this.tags, required this.totalMins});
  final List<TagStat> tags;
  final int totalMins;

  static const _tagColors = [
    ScreenSageColors.accent,
    ScreenSageColors.violet,
    ScreenSageColors.blue,
    ScreenSageColors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus by Tag', style: ScreenSageTextStyles.titleMedium),
            const SizedBox(height: 16),
            ...tags.asMap().entries.map((entry) {
              final tag = entry.value;
              final color = _tagColors[entry.key % _tagColors.length];
              final ratio =
                  totalMins > 0 ? (tag.mins / totalMins).clamp(0.0, 1.0) : 0.0;
              final pct = (ratio * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tag.tag, style: ScreenSageTextStyles.bodyMedium),
                        Text(
                          '${_fmt(tag.mins)}  ·  $pct%',
                          style: ScreenSageTextStyles.labelSmall
                              .copyWith(color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: ScreenSageColors.border,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _fmt(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ── Focus Mode Breakdown ──────────────────────────────────────────
class _FocusModeBreakdown extends StatelessWidget {
  const _FocusModeBreakdown({required this.modes});
  final Map<String, int> modes;

  static const _modeEmoji = {
    'deep': '🧠',
    'flow': '🌊',
    'sprint': '⚡',
    'custom': '🎯',
  };

  static String _fmt(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = modes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus Mode Usage', style: ScreenSageTextStyles.titleMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sorted.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ScreenSageColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ScreenSageColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _modeEmoji[entry.key] ?? '🎯',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key[0].toUpperCase() + entry.key.substring(1),
                            style: ScreenSageTextStyles.labelSmall.copyWith(
                              color: ScreenSageColors.textSecondary,
                            ),
                          ),
                          Text(
                            _fmt(entry.value),
                            style: ScreenSageTextStyles.labelMedium.copyWith(
                              color: ScreenSageColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

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
        children: [
          Text(label, style: ScreenSageTextStyles.labelSmall),
          const SizedBox(height: 6),
          Text(value,
              style:
                  ScreenSageTextStyles.headlineMedium.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(sub, style: ScreenSageTextStyles.bodySmall),
        ],
      ),
    );
  }
}
