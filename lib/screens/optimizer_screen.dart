import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/optimizer_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_card.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';

/// System Optimizer — a sketched dashboard of analog dials showing REAL device
/// metrics (battery, app storage) + a big SWEEP button that genuinely clears
/// the app's cache directory.
class OptimizerScreen extends ConsumerWidget {
  const OptimizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(optimizerProvider);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tune the machine.',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth > 620 ? 2 : 1;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: (c.maxWidth / cols) - 14,
                        child: _AnalogGauge(
                          icon: SketchIconType.battery,
                          label: 'Battery',
                          value: state.batteryLevel,
                          sub:
                              '${(state.batteryLevel * 100).round()}%',
                        ),
                      ),
                      SizedBox(
                        width: (c.maxWidth / cols) - 14,
                        child: _AnalogGauge(
                          icon: SketchIconType.folder,
                          label: 'App storage',
                          value: (state.appStorageMb / 1024).clamp(0.0, 1.0),
                          sub:
                              '${state.appStorageMb.toStringAsFixed(1)} MB',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              // Real device info card.
              SketchyCard(
                title: 'Device info',
                icon: SketchIconType.device,
                child: Column(
                  children: [
                    _infoRow(context, 'Device', state.deviceName),
                    _infoRow(context, 'OS', state.osVersion),
                    _infoRow(context, 'CPU cores', '${state.cpuCores}'),
                    _infoRow(context, 'App storage', '${state.appStorageMb.toStringAsFixed(1)} MB'),
                    if (state.sampledAt != null)
                      _infoRow(context, 'Last sampled', _timeAgo(state.sampledAt!)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 220,
                      child: SketchyButton(
                        label: state.sweeping ? 'Sweeping…' : 'SWEEP',
                        icon:
                            const SketchIcon(SketchIconType.broom, size: 22),
                        fontFamily: 'Caveat',
                        fontSize: 30,
                        bold: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        disabled: state.sweeping,
                        onPressed: state.sweeping
                            ? null
                            : () => ref
                                .read(optimizerProvider.notifier)
                                .sweep(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (state.lastFreedMb > 0)
                      Text(
                        'Last sweep freed ${state.lastFreedMb} MB · '
                        'total freed ${state.totalFreedMb} MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Text(
                        'Tap SWEEP to clear the app cache and free space.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (state.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontFamily: 'Inter',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (state.sweeping) const _BroomOverlay(),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _AnalogGauge extends StatelessWidget {
  const _AnalogGauge({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  final SketchIconType icon;
  final String label;
  final double value; // 0..1
  final String sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SketchyCard(
      icon: icon,
      title: label,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: value.clamp(0.0, 1.0),
                  isDark: theme.brightness == Brightness.dark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Real-time from device',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.isDark});
  final double value;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    final center = Offset(size.width / 2, size.height / 2 + 6);
    final radius = (size.width / 2) - 8;

    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const start = math.pi;
    const sweep = math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );

    final tickPaint = Paint()
      ..color = ink.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i <= 10; i++) {
      final t = i / 10;
      final ang = start + sweep * t;
      final outer = Offset(
        center.dx + (radius) * math.cos(ang),
        center.dy + (radius) * math.sin(ang),
      );
      final inner = Offset(
        center.dx + (radius - 8) * math.cos(ang),
        center.dy + (radius - 8) * math.sin(ang),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final needleAng = start + sweep * value.clamp(0.0, 1.0);
    final needleEnd = Offset(
      center.dx + (radius - 14) * math.cos(needleAng),
      center.dy + (radius - 14) * math.sin(needleAng),
    );
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = ink
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      5,
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.isDark != isDark;
}

class _BroomOverlay extends StatefulWidget {
  const _BroomOverlay();

  @override
  State<_BroomOverlay> createState() => _BroomOverlayState();
}

class _BroomOverlayState extends State<_BroomOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final w = MediaQuery.of(context).size.width;
          final x = -80 + t * (w + 160);
          return Stack(
            children: [
              Container(
                color: Colors.black.withValues(alpha: 0.08),
              ),
              Positioned(
                left: x,
                top: MediaQuery.of(context).size.height * 0.42,
                child: Transform.rotate(
                  angle: -0.3 + math.sin(t * math.pi * 4) * 0.1,
                  child: const SketchIcon(SketchIconType.broom, size: 90),
                ),
              ),
              Positioned(
                left: x - 30,
                top: MediaQuery.of(context).size.height * 0.48,
                child: Opacity(
                  opacity: 0.4 * (1 - t),
                  child: const SketchIcon(SketchIconType.erase, size: 40),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
