import 'package:flutter/material.dart';
import '../theme/sketchy_constants.dart';
import 'sketchy_container.dart';
import 'sketchy_icons.dart';

/// A sketched card surface with an optional title row, used across screens.
class SketchyCard extends StatelessWidget {
  const SketchyCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.fillColor,
    this.strokeColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.roughness = 1.0,
    this.shadow = false,
    this.onTap,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final SketchIconType? icon;
  final Widget? trailing;
  final Color? fillColor;
  final Color? strokeColor;
  final EdgeInsets padding;
  final double borderRadius;
  final double roughness;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SketchyContainer(
      fillColor: fillColor,
      strokeColor: strokeColor,
      borderRadius: borderRadius,
      roughness: roughness,
      shadow: shadow,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null || icon != null || trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          SketchIcon(icon!,
                              size: 22, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null)
                                Text(
                                  title!,
                                  style: theme.textTheme.titleMedium,
                                ),
                              if (subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    subtitle!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sketched divider — a slightly wobbly horizontal line.
class SketchyDivider extends StatelessWidget {
  const SketchyDivider({
    super.key,
    this.height = 1.6,
    this.color,
    this.indent = 0,
  });

  final double height;
  final Color? color;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: CustomPaint(
        size: Size.infinite,
        painter: _WobbleLinePainter(
          color: color ?? theme.colorScheme.outline,
          strokeWidth: height,
        ),
      ),
    );
  }
}

class _WobbleLinePainter extends CustomPainter {
  _WobbleLinePainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rng = SketchRng(size.width.toInt());
    const steps = 24;
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = size.width * t;
      final y = size.height / 2 +
          sketchWobble(rng, strokeWidth * 0.8).dy * (i == 0 || i == steps ? 0 : 1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WobbleLinePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// A sketched circular badge (e.g. for counts / status dots).
class SketchyBadge extends StatelessWidget {
  const SketchyBadge({
    super.key,
    required this.label,
    this.color,
    this.fillColor,
  });

  final String label;
  final Color? color;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke =
        color ?? (isDark ? SketchPalette.chalkInk : SketchPalette.inkLight);
    return SketchyContainer(
      fillColor: fillColor ?? stroke,
      strokeColor: stroke,
      strokeWidth: 1.5,
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      roughness: 0.8,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? SketchPalette.chalkboard : SketchPalette.paperLight,
        ),
      ),
    );
  }
}
