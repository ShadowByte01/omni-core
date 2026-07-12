import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sketchy_constants.dart';

/// A lightweight, procedural "paper grain" background rendered via a
/// [CustomPainter] on the raster thread. Instead of shipping a heavy image
/// asset, we synthesise a deterministic field of faint graphite specks and
/// faint crease lines that look like textured sketch paper.
///
/// The painter is wrapped in a [RepaintBoundary] so the grain is rasterised
/// once and cached — guaranteeing zero lag during scroll/animation.
///
/// In dark mode the same field inverts to look like a black chalkboard with
/// white chalk dust.
class PaperBackground extends StatefulWidget {
  const PaperBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.showCreases = true,
  });

  final Widget child;
  final double intensity;
  final bool showCreases;

  @override
  State<PaperBackground> createState() => _PaperBackgroundState();
}

class _PaperBackgroundState extends State<PaperBackground> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PaperGrainPainter(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              intensity: widget.intensity,
              showCreases: widget.showCreases,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  _PaperGrainPainter({
    required this.width,
    required this.height,
    required this.intensity,
    required this.showCreases,
    required this.isDark,
  });

  final double width;
  final double height;
  final double intensity;
  final bool showCreases;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor =
        isDark ? SketchPalette.chalkboard : SketchPalette.paperLight;
    // Base wash.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = baseColor,
    );

    // Subtle warm/cool gradient wash for depth (very faint).
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                SketchPalette.chalkboardDeep,
                SketchPalette.chalkboard,
              ]
            : [
                SketchPalette.paperWarm.withValues(alpha: 0.6),
                SketchPalette.paperLight,
              ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    // Grain specks — deterministic field.
    final rng = SketchRng(42);
    final speckColor = isDark
        ? SketchPalette.chalkSoft
        : SketchPalette.graphite4;
    final speckPaint = Paint()..strokeCap = StrokeCap.round;

    // Density scales with area, capped for performance.
    final area = size.width * size.height;
    final count = (area / 90).clamp(400, 2600).toInt();

    for (int i = 0; i < count; i++) {
      final x = rng.next(max: size.width);
      final y = rng.next(max: size.height);
      final len = rng.next(min: 0.4, max: 1.8) * intensity;
      final a = rng.next(min: 0.02, max: 0.10) * intensity;
      speckPaint.color = speckColor.withValues(alpha: a);
      speckPaint.strokeWidth = rng.next(min: 0.4, max: 0.9);
      final ang = rng.next(max: math.pi);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(ang) * len, y + math.sin(ang) * len),
        speckPaint,
      );
    }

    // A few faint paper creases.
    if (showCreases) {
      final creasePaint = Paint()
        ..color = (isDark ? SketchPalette.chalkDim : SketchPalette.graphite5)
            .withValues(alpha: 0.10)
        ..strokeWidth = 0.8;
      final crng = SketchRng(9001);
      for (int i = 0; i < 3; i++) {
        final sx = crng.next(max: size.width);
        final sy = crng.next(max: size.height);
        final ex = sx + crng.next(min: -80, max: 80);
        final ey = sy + crng.next(min: 30, max: 90);
        canvas.drawLine(Offset(sx, sy), Offset(ex, ey), creasePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter old) {
    return old.width != width ||
        old.height != height ||
        old.intensity != intensity ||
        old.isDark != isDark ||
        old.showCreases != showCreases;
  }
}
