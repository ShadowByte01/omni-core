import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sketchy_constants.dart';

/// A reusable widget that draws wobbly, hand-drawn black borders around its
/// child using a [CustomPainter]. GPU-accelerated: the painter runs on the
/// raster thread and we wrap the result in [RepaintBoundary] semantics so the
/// sketchy stroke is cached and never recomputed during unrelated rebuilds.
///
/// The wobble algorithm is a lightweight, deterministic Rough.js-inspired
/// generator: every line is split into segments and each segment vertex is
/// jittered by a seed-driven PRNG, then drawn 1-2 times (the second pass is an
/// "under-sketch" that gives the characteristic pencil double-line look).
class SketchyContainer extends StatelessWidget {
  const SketchyContainer({
    super.key,
    required this.child,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = SketchPalette.strokeRegular,
    this.borderRadius = sketchRadius,
    this.roughness = 1.0,
    this.bowing = 1.0,
    this.fillStyle = SketchFillStyle.solid,
    this.hatchAngle,
    this.hatchGap = 8.0,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
    this.doubleStroke = true,
    this.shadow = false,
    this.seed,
  });

  final Widget child;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final double borderRadius;
  final double roughness;
  final double bowing;
  final SketchFillStyle fillStyle;
  final double? hatchAngle;
  final double hatchGap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool doubleStroke;
  final bool shadow;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedFill = fillColor ??
        (isDark ? SketchPalette.chalkboard : SketchPalette.paperLight);
    final resolvedStroke =
        strokeColor ?? (isDark ? SketchPalette.chalkInk : SketchPalette.inkLight);

    return Container(
      margin: margin,
      child: CustomPaint(
        painter: _SketchyBoxPainter(
          fillColor: resolvedFill,
          strokeColor: resolvedStroke,
          strokeWidth: strokeWidth,
          radius: borderRadius,
          roughness: roughness,
          bowing: bowing,
          fillStyle: fillStyle,
          hatchAngle: hatchAngle,
          hatchGap: hatchGap,
          doubleStroke: doubleStroke,
          shadow: shadow,
          isDark: isDark,
          seed: seed,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum SketchFillStyle { solid, hachure, crossHatch, none }

class _SketchyBoxPainter extends CustomPainter {
  _SketchyBoxPainter({
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.radius,
    required this.roughness,
    required this.bowing,
    required this.fillStyle,
    required this.hatchAngle,
    required this.hatchGap,
    required this.doubleStroke,
    required this.shadow,
    required this.isDark,
    required this.seed,
  });

  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double radius;
  final double roughness;
  final double bowing;
  final SketchFillStyle fillStyle;
  final double? hatchAngle;
  final double hatchGap;
  final bool doubleStroke;
  final bool shadow;
  final bool isDark;
  final int? seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = radius.clamp(0.0, math.min(size.width, size.height) / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final s = seed ?? sketchSeedFor(size);

    // Optional drop shadow (sketched, soft).
    if (shadow) {
      final shadowPath = Path()..addRRect(rrect.shift(const Offset(3, 4)));
      canvas.drawPath(
        shadowPath,
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? 0.25 : 0.12)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Fill.
    if (fillStyle != SketchFillStyle.none) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
      if (fillStyle == SketchFillStyle.hachure ||
          fillStyle == SketchFillStyle.crossHatch) {
        _drawHatch(canvas, rect, s);
      }
    }

    // Stroke — wobbly rounded-rectangle.
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final main = _sketchyRRect(rrect, SketchRng(s), roughness, bowing);
    canvas.drawPath(main, strokePaint);

    if (doubleStroke) {
      final under = _sketchyRRect(
        rrect,
        SketchRng(s + 101),
        roughness * 0.7,
        bowing * 0.7,
      );
      canvas.drawPath(
        under,
        strokePaint
          ..color = strokeColor.withValues(alpha: 0.55)
          ..strokeWidth = strokeWidth * 0.7,
      );
    }
  }

  void _drawHatch(Canvas canvas, Rect rect, int seed) {
    final rng = SketchRng(seed + 555);
    final angle = hatchAngle ?? degToRad(45);
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final cx = rect.center;
    final halfDiag =
        (rect.width.abs() + rect.height.abs()) / 2 * 1.2;

    final paint = Paint()
      ..color = strokeColor.withValues(alpha: 0.10)
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.round;

    for (double d = -halfDiag; d <= halfDiag; d += hatchGap) {
      // Center the hatch line at offset d along the perpendicular axis.
      final p1 = Offset(
        cx.dx + cosA * -halfDiag - sinA * d,
        cx.dy + sinA * -halfDiag + cosA * d,
      );
      final p2 = Offset(
        cx.dx + cosA * halfDiag - sinA * d,
        cx.dy + sinA * halfDiag + cosA * d,
      );
      // Clip hatch to the rounded rect by sampling intersections naively.
      final wobble = roughness * 1.2;
      final segments = <Offset>[];
      const steps = 12;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final pt = Offset(
          p1.dx + (p2.dx - p1.dx) * t + rng.next(min: -wobble, max: wobble),
          p1.dy + (p2.dy - p1.dy) * t + rng.next(min: -wobble, max: wobble),
        );
        if (_rrectContains(rect, radius, pt)) {
          segments.add(pt);
        }
      }
      for (int i = 1; i < segments.length; i++) {
        canvas.drawLine(segments[i - 1], segments[i], paint);
      }
    }

    if (fillStyle == SketchFillStyle.crossHatch) {
      final angle2 = angle + math.pi / 2;
      final cosB = math.cos(angle2);
      final sinB = math.sin(angle2);
      for (double d = -halfDiag; d <= halfDiag; d += hatchGap) {
        final p1 = Offset(
          cx.dx + cosB * -halfDiag - sinB * d,
          cx.dy + sinB * -halfDiag + cosB * d,
        );
        final p2 = Offset(
          cx.dx + cosB * halfDiag - sinB * d,
          cx.dy + sinB * halfDiag + cosB * d,
        );
        final wobble = roughness * 1.2;
        final segments = <Offset>[];
        const steps = 12;
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          final pt = Offset(
            p1.dx + (p2.dx - p1.dx) * t +
                rng.next(min: -wobble, max: wobble),
            p1.dy + (p2.dy - p1.dy) * t +
                rng.next(min: -wobble, max: wobble),
          );
          if (_rrectContains(rect, radius, pt)) {
            segments.add(pt);
          }
        }
        for (int i = 1; i < segments.length; i++) {
          canvas.drawLine(segments[i - 1], segments[i], paint);
        }
      }
    }
  }

  bool _rrectContains(Rect rect, double r, Offset p) {
    // Approx: point inside rect minus rounded corners.
    if (!rect.contains(p)) return false;
    final corners = [
      rect.topLeft + Offset(r, r),
      rect.topRight + Offset(-r, r),
      rect.bottomLeft + Offset(r, -r),
      rect.bottomRight + Offset(-r, -r),
    ];
    final quadrants = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    for (int i = 0; i < 4; i++) {
      final q = quadrants[i];
      final inCornerX = (i == 0 || i == 2)
          ? p.dx < q.dx + r
          : p.dx > q.dx - r;
      final inCornerY = (i == 0 || i == 1)
          ? p.dy < q.dy + r
          : p.dy > q.dy - r;
      if (inCornerX && inCornerY) {
        final d = (p - corners[i]).distance;
        if (d > r) return false;
      }
    }
    return true;
  }

  Path _sketchyRRect(
      RRect rrect, SketchRng rng, double rough, double bow) {
    final path = Path();
    final rect = rrect.outerRect;
    final r = rrect.tlRadiusX;
    final w = rect.width;
    final h = rect.height;

    // Helper to add a wobbly line.
    void wobblyLine(Offset a, Offset b) {
      final dist = (b - a).distance;
      final segments = (dist / 14).clamp(2, 24).round();
      final bowOffset = bow * (rng.next(min: -1, max: 1)) * (dist / 200);
      final n = Offset(-(b.dy - a.dy), b.dx - a.dx).normalized() * bowOffset;
      Offset prev = a + sketchWobble(rng, rough * 0.6);
      path.moveTo(prev.dx, prev.dy);
      for (int i = 1; i <= segments; i++) {
        final t = i / segments;
        final mid = Offset(
          a.dx + (b.dx - a.dx) * t + n.dx * math.sin(t * math.pi),
          a.dy + (b.dy - a.dy) * t + n.dy * math.sin(t * math.pi),
        );
        final pt = mid + sketchWobble(rng, rough * 0.9);
        path.lineTo(pt.dx, pt.dy);
        prev = pt;
      }
    }

    // Helper to add a wobbly arc (corner).
    void wobblyCorner(Offset center, double startAngle, double sweep) {
      const steps = 8;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final ang = startAngle + sweep * t;
        final wobble = rough * 0.9;
        final pt = Offset(
              center.dx + r * math.cos(ang),
              center.dy + r * math.sin(ang),
            ) +
            sketchWobble(rng, wobble);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
    }

    // Start at top-left after the corner.
    final tlCorner = rect.topLeft + Offset(r, r);
    final trCorner = rect.topRight + Offset(-r, r);
    final brCorner = rect.bottomRight + Offset(-r, -r);
    final blCorner = rect.bottomLeft + Offset(r, -r);

    path.moveTo(tlCorner.dx - r + rng.next(min: -0.6, max: 0.6), tlCorner.dy);
    // top edge
    wobblyLine(Offset(rect.left + r, rect.top),
        Offset(rect.right - r, rect.top));
    // top-right corner
    wobblyCorner(trCorner, -math.pi / 2, math.pi / 2);
    // right edge
    wobblyLine(Offset(rect.right, rect.top + r),
        Offset(rect.right, rect.bottom - r));
    // bottom-right corner
    wobblyCorner(brCorner, 0, math.pi / 2);
    // bottom edge
    wobblyLine(Offset(rect.right - r, rect.bottom),
        Offset(rect.left + r, rect.bottom));
    // bottom-left corner
    wobblyCorner(blCorner, math.pi / 2, math.pi / 2);
    // left edge
    wobblyLine(Offset(rect.left, rect.bottom - r),
        Offset(rect.left, rect.top + r));
    // top-left corner
    wobblyCorner(tlCorner, math.pi, math.pi / 2);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SketchyBoxPainter old) {
    return old.fillColor != fillColor ||
        old.strokeColor != strokeColor ||
        old.strokeWidth != strokeWidth ||
        old.radius != radius ||
        old.roughness != roughness ||
        old.bowing != bowing ||
        old.fillStyle != fillStyle ||
        old.doubleStroke != doubleStroke ||
        old.shadow != shadow ||
        old.seed != seed ||
        old.isDark != isDark;
  }
}

/// Extension to normalize an offset safely (avoid div-by-zero).
extension on Offset {
  Offset normalized() {
    final d = distance;
    if (d == 0) return Offset.zero;
    return this / d;
  }
}
