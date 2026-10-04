import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../analytics/data/repositories/analytics_repository.dart';

class FocusConstellation extends StatefulWidget {
  const FocusConstellation({super.key, required this.sessions});
  final List<AnalyticsSession> sessions;

  @override
  State<FocusConstellation> createState() => _FocusConstellationState();
}

class _FocusConstellationState extends State<FocusConstellation>
    with TickerProviderStateMixin {
  late AnimationController _twinkle;
  late AnimationController _entry;
  final _repaintKey = GlobalKey();
  final _exportRepaintKey = GlobalKey();
  bool _isSharing = false;
  int? _tappedIndex; // for tap-to-reveal session detail

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Constellation',
                      style: ScreenSageTextStyles.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    widget.sessions.isEmpty
                        ? 'Complete sessions to light up your sky'
                        : '${widget.sessions.length} stars · 30 day sky',
                    style: ScreenSageTextStyles.bodySmall
                        .copyWith(color: ScreenSageColors.textTertiary),
                  ),
                ],
              ),
              if (widget.sessions.isNotEmpty)
                GestureDetector(
                  onTap: _isSharing ? null : _share,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: ScreenSageColors.accentSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ScreenSageColors.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isSharing
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: ScreenSageColors.accent,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded,
                                size: 14, color: ScreenSageColors.accent),
                        const SizedBox(width: 6),
                        Text('Share',
                            style: ScreenSageTextStyles.labelSmall
                                .copyWith(color: ScreenSageColors.accent)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 16),

        // ── Full-width sky — no card border ────────────────
        RepaintBoundary(
          key: _repaintKey,
          child: _buildConstellation(isExportVersion: false),
        ).animate().fadeIn(
              delay: 200.ms,
              duration: 1000.ms,
            ),

        Offstage(
          offstage: true,
          child: RepaintBoundary(
            key: _exportRepaintKey,
            child: _buildConstellation(isExportVersion: true),
          ),
        ),
        // ── Legend + insight strip ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: const [
                    _LegendDot(color: ScreenSageColors.accent, label: 'Deep'),
                    _LegendDot(color: ScreenSageColors.violet, label: 'Flow'),
                    _LegendDot(color: ScreenSageColors.amber, label: 'Sprint'),
                    _LegendDot(color: ScreenSageColors.blue, label: 'Custom'),
                  ],
                ),
              ),
              // Peak time insight
              if (widget.sessions.isNotEmpty)
                _PeakTimeChip(sessions: widget.sessions),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms),

        // ── Insight sentence ───────────────────────────────
        if (widget.sessions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              _buildInsight(),
              style: ScreenSageTextStyles.bodySmall
                  .copyWith(color: ScreenSageColors.textTertiary),
            ),
          ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  Widget _buildConstellation({
    required bool isExportVersion,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 340,
      child: Stack(
        children: [
          // ── Deep space gradient ─────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _ConstellationPainter._skyColors(),
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Nebula glow patches ─────────────────────────────
          Positioned(
            top: 40,
            left: 60,
            child: Container(
              width: 200,
              height: 130,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _ConstellationPainter._nebulaColor().withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            right: 30,
            child: Container(
              width: 160,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _ConstellationPainter._nebulaColor().withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Star map ────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_twinkle, _entry]),
            builder: (context, _) {
              return GestureDetector(
                onTapUp: isExportVersion
                    ? null
                    : (details) => _handleTap(details.localPosition),
                child: CustomPaint(
                  size: Size(
                    MediaQuery.of(context).size.width,
                    340,
                  ),
                  painter: _ConstellationPainter(
                    sessions: widget.sessions,
                    twinkleValue: _twinkle.value,
                    entryProgress: _entry.value,
                  ),
                ),
              );
            },
          ),

          // ── Tooltip only on visible version ─────────────────
          if (!isExportVersion &&
              _tappedIndex != null &&
              _tappedIndex! < widget.sessions.length)
            _SessionTooltip(
              session: widget.sessions[_tappedIndex!],
              onDismiss: () => setState(() => _tappedIndex = null),
            ),

          // ── Time axis ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    _TimeLabel('12am'),
                    _TimeLabel('6am'),
                    _TimeLabel('12pm'),
                    _TimeLabel('6pm'),
                    _TimeLabel('12am'),
                  ],
                ),
              ),
            ),
          ),

          // ── EXPORT ONLY ─────────────────────────────────────
          if (isExportVersion)
            Positioned(
              right: 14,
              bottom: 38,
              child: _ConstellationBranding(),
            ),
        ],
      ),
    );
  }

  String _buildInsight() {
    if (widget.sessions.isEmpty) return '';
    final hours = widget.sessions.map((s) => s.startedAt.hour).toList();
    final avgHour = hours.reduce((a, b) => a + b) ~/ hours.length;
    final timeLabel = avgHour < 12
        ? 'morning'
        : avgHour < 17
            ? 'afternoon'
            : 'evening';
    final completed = widget.sessions.where((s) => s.completed).length;
    final pct = (completed / widget.sessions.length * 100).round();
    return 'You focus most in the $timeLabel · $pct% completion rate · tap any star for details';
  }

  void _handleTap(Offset position) {
    // Find which star was tapped
    final size = Size(MediaQuery.of(context).size.width, 340);
    final now = DateTime.now();

    for (int i = 0; i < widget.sessions.length; i++) {
      final s = widget.sessions[i];
      final hour = s.startedAt.hour + s.startedAt.minute / 60.0;
      final x = (hour / 24.0) * size.width;
      final daysDiff = now.difference(s.startedAt).inDays.clamp(0, 30);
      final y = size.height * 0.1 + (daysDiff / 30.0) * size.height * 0.75;

      if ((position - Offset(x, y)).distance < 20) {
        HapticFeedback.lightImpact();
        setState(() => _tappedIndex = i);
        return;
      }
    }
    setState(() => _tappedIndex = null);
  }

  Future<void> _share() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSharing = true);

    try {
      // Make sure the hidden export widget has completed layout.
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _exportRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return;

      final image = await boundary.toImage(
        pixelRatio: 3.0,
      );

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return;

      final dir = await getTemporaryDirectory();

      final file = File(
        '${dir.path}/my_constellation.png',
      );

      await file.writeAsBytes(
        byteData.buffer.asUint8List(),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path),
          ],
          text: 'My focus constellation ✨\n'
              '${widget.sessions.length} sessions. Building something real.\n\n'
              'ScreenSage 🧠\nscreensage.app',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

class _ConstellationBranding extends StatelessWidget {
  const _ConstellationBranding();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icons/SS_icon_2.png',
          height: 12,
          width: 12,
        ),
        const SizedBox(width: 5),
        Text(
          'ScreenSage',
          style: ScreenSageTextStyles.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(5),
          ),
          child: QrImageView(
            data: 'https://screensage.app/get?src=constellation',
            version: QrVersions.auto,
            size: 34,
            gapless: true,
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Constellation Painter ─────────────────────────────────────────
class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter({
    required this.sessions,
    required this.twinkleValue,
    required this.entryProgress,
  });

  // Add this static method to _ConstellationPainter
  static List<Color> _skyColors() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 7) {
      // Dawn — deep purple fading to orange blush
      return const [Color(0xFF1A0A2E), Color(0xFF3D1C4A), Color(0xFF7B3F6E)];
    } else if (hour >= 7 && hour < 10) {
      // Morning — warm indigo to soft gold
      return const [Color(0xFF0D1B3E), Color(0xFF1E3A5F), Color(0xFF4A6FA5)];
    } else if (hour >= 10 && hour < 16) {
      // Midday — deepest blue (still dark for contrast, stars visible)
      return const [Color(0xFF000D1A), Color(0xFF001428), Color(0xFF002244)];
    } else if (hour >= 16 && hour < 19) {
      // Golden hour — dark amber tones
      return const [Color(0xFF0D0A00), Color(0xFF1A1000), Color(0xFF3D2800)];
    } else if (hour >= 19 && hour < 21) {
      // Dusk — deep crimson to purple
      return const [Color(0xFF0F0005), Color(0xFF2A0A1F), Color(0xFF4A1040)];
    } else {
      // Night — true deep space
      return const [Color(0xFF000814), Color(0xFF000D20), Color(0xFF001028)];
    }
  }

  static Color _nebulaColor() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 7) return const Color(0xFFFF6B9D); // dawn — pink
    if (hour >= 7 && hour < 10) {
      return const Color(0xFF4A90E2); // morning — blue
    }
    if (hour >= 10 && hour < 16) return ScreenSageColors.accent; // day — green
    if (hour >= 16 && hour < 19) {
      return const Color(0xFFFFAA44); // golden — amber
    }
    if (hour >= 19 && hour < 21) {
      return const Color(0xFFE040FB); // dusk — magenta
    }
    return ScreenSageColors.violet; // night — violet
  }

  final List<AnalyticsSession> sessions;
  final double twinkleValue;
  final double entryProgress; // 0→1, stars appear progressively

  static const _modeColors = {
    'deep': ScreenSageColors.accent,
    'flow': ScreenSageColors.violet,
    'sprint': ScreenSageColors.amber,
    'custom': ScreenSageColors.blue,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(99);

    // ── Milky way dust (very subtle) ───────────────────────
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 0.8 + 0.2;
      final opacity = rng.nextDouble() * 0.25 * (0.6 + 0.4 * twinkleValue);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }

    if (sessions.isEmpty) {
      _drawEmptyGuide(canvas, size);
      return;
    }

    final now = DateTime.now();

    // ── Draw constellation lines first (behind stars) ──────
    _drawConstellationLines(canvas, size, now);

    // ── Draw session stars ─────────────────────────────────
    for (int i = 0; i < sessions.length; i++) {
      // Entry animation — stars appear one by one
      final threshold = i / sessions.length.clamp(1, 999);
      if (entryProgress < threshold) continue;
      final starEntry =
          ((entryProgress - threshold) / (1.0 / sessions.length.clamp(1, 999)))
              .clamp(0.0, 1.0);

      final s = sessions[i];
      final hour = s.startedAt.hour + s.startedAt.minute / 60.0;
      final x = (hour / 24.0) * size.width;
      final daysDiff = now.difference(s.startedAt).inDays.clamp(0, 30);
      // Recent sessions near top, older near bottom
      final y = size.height * 0.1 + (daysDiff / 30.0) * size.height * 0.75;

      // Size by duration — 5m=small, 60m=large
      final baseRadius = (s.durationMins / 60.0).clamp(0.15, 1.0) * 9 + 2.5;

      // Twinkle — unique phase per star
      final phase = (i * 0.618) % 1.0; // golden ratio spacing
      final twinkle = 0.85 + 0.15 * sin((twinkleValue + phase) * 2 * pi);
      final radius = baseRadius * twinkle * starEntry;

      final color = _modeColors[s.focusMode] ?? ScreenSageColors.accent;
      final opacity = s.completed
          ? (0.7 + 0.3 * twinkle) * starEntry
          : 0.3 * starEntry; // incomplete = dim

      // Outer corona glow
      canvas.drawCircle(
        Offset(x, y),
        radius * 2.5,
        Paint()
          ..color = color.withOpacity(0.12 * twinkle * starEntry)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Mid glow
      canvas.drawCircle(
        Offset(x, y),
        radius * 1.5,
        Paint()
          ..color = color.withOpacity(0.25 * twinkle * starEntry)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Star shape
      _drawStar(
        canvas,
        Offset(x, y),
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );

      // White hot center for completed sessions
      if (s.completed) {
        canvas.drawCircle(
          Offset(x, y),
          radius * 0.3,
          Paint()..color = Colors.white.withOpacity(0.7 * twinkle * starEntry),
        );
      }
    }
  }

  void _drawConstellationLines(Canvas canvas, Size size, DateTime now) {
    // Group by day — connect sessions on the same day
    final byDay = <String, List<AnalyticsSession>>{};
    for (final s in sessions) {
      if (!s.completed) continue;
      final key = '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}';
      byDay.putIfAbsent(key, () => []).add(s);
    }

    final linePaint = Paint()
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (final daySessions in byDay.values) {
      if (daySessions.length < 2) continue;
      // Sort by time
      daySessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));

      for (int i = 0; i < daySessions.length - 1; i++) {
        final a = daySessions[i];
        final b = daySessions[i + 1];

        final ax =
            (a.startedAt.hour + a.startedAt.minute / 60.0) / 24.0 * size.width;
        final bx =
            (b.startedAt.hour + b.startedAt.minute / 60.0) / 24.0 * size.width;
        final aDays = now.difference(a.startedAt).inDays.clamp(0, 30);
        final bDays = now.difference(b.startedAt).inDays.clamp(0, 30);
        final ay = size.height * 0.1 + (aDays / 30.0) * size.height * 0.75;
        final by = size.height * 0.1 + (bDays / 30.0) * size.height * 0.75;

        // Color fades with age
        final opacity = (1.0 - aDays / 30.0).clamp(0.05, 0.25) * entryProgress;
        linePaint.color = ScreenSageColors.accent.withOpacity(opacity);

        // Dashed line
        _drawDashedLine(canvas, Offset(ax, ay), Offset(bx, by), linePaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 4.0;
    const gapLength = 4.0;
    final total = (end - start).distance;
    final dir = (end - start) / total;
    double drawn = 0;
    bool drawing = true;
    while (drawn < total) {
      final segLen = drawing ? dashLength : gapLength;
      final next = drawn + segLen;
      if (drawing) {
        canvas.drawLine(
          start + dir * drawn,
          start + dir * next.clamp(0, total),
          paint,
        );
      }
      drawn = next;
      drawing = !drawing;
    }
  }

  void _drawEmptyGuide(Canvas canvas, Size size) {
    // Show a subtle placeholder ring suggesting stars to come
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      60,
      Paint()
        ..color = ScreenSageColors.accent.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = ScreenSageColors.accent.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 5;
    final inner = radius * 0.42;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final r = i.isEven ? radius : inner;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.twinkleValue != twinkleValue ||
      old.entryProgress != entryProgress ||
      old.sessions != sessions;
}

// ── Tap tooltip ───────────────────────────────────────────────────
class _SessionTooltip extends StatelessWidget {
  const _SessionTooltip({required this.session, required this.onDismiss});
  final AnalyticsSession session;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final time =
        '${session.startedAt.hour.toString().padLeft(2, '0')}:${session.startedAt.minute.toString().padLeft(2, '0')}';
    final date = '${session.startedAt.day}/${session.startedAt.month}';

    return Positioned(
      top: 12,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ScreenSageColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ScreenSageColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Text(
                session.completed ? '⭐' : '💫',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.intention.isNotEmpty
                          ? '"${session.intention}"'
                          : session.focusMode.isNotEmpty
                              ? '${session.focusMode[0].toUpperCase()}${session.focusMode.substring(1)} session'
                              : 'Focus session',
                      style: ScreenSageTextStyles.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$date at $time · ${session.durationMins}m · ${session.completed ? 'Completed' : 'Incomplete'}',
                      style: ScreenSageTextStyles.bodySmall
                          .copyWith(color: ScreenSageColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.close,
                  size: 14, color: ScreenSageColors.textTertiary),
            ],
          ),
        ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1),
      ),
    );
  }
}

// ── Peak time chip ────────────────────────────────────────────────
class _PeakTimeChip extends StatelessWidget {
  const _PeakTimeChip({required this.sessions});
  final List<AnalyticsSession> sessions;

  @override
  Widget build(BuildContext context) {
    final hours = sessions.map((s) => s.startedAt.hour).toList();
    final avg = hours.reduce((a, b) => a + b) ~/ hours.length;
    final emoji = avg < 12
        ? '🌅'
        : avg < 17
            ? '☀️'
            : '🌙';
    final label = avg < 12
        ? 'Morning'
        : avg < 17
            ? 'Afternoon'
            : 'Night';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text('Peak: $label',
              style: ScreenSageTextStyles.bodySmall
                  .copyWith(color: ScreenSageColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Supporting ────────────────────────────────────────────────────
class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: ScreenSageTextStyles.bodySmall.copyWith(
        color: Colors.white.withOpacity(0.3),
        fontSize: 9,
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: ScreenSageTextStyles.bodySmall),
      ],
    );
  }
}
