import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/sketchy_constants.dart';
import 'sketchy_container.dart';

/// A hand-drawn sketchy button built on top of [SketchyContainer] with spring
/// physics feedback. All transitions use spring curves — never linear.
class SketchyButton extends StatefulWidget {
  const SketchyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leadingIcon,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = SketchPalette.strokeRegular,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.fontSize = 16,
    this.fontFamily,
    this.bold = false,
    this.roughness = 1.0,
    this.disabled = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? leadingIcon;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final double borderRadius;
  final EdgeInsets padding;
  final double fontSize;
  final String? fontFamily;
  final bool bold;
  final double roughness;
  final bool disabled;
  final bool expand;

  @override
  State<SketchyButton> createState() => _SketchyButtonState();
}

class _SketchyButtonState extends State<SketchyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SketchPalette.quick,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tapDown() {
    _controller.animateTo(1, curve: SketchPalette.springSoft);
  }

  void _tapUp() {
    _controller.animateBack(0, curve: SketchPalette.springCurve);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = widget.strokeColor ??
        (isDark ? SketchPalette.chalkInk : SketchPalette.inkLight);
    final baseFill = widget.fillColor ??
        (isDark ? SketchPalette.chalkboard : SketchPalette.paperLight);

    final enabled = widget.onPressed != null && !widget.disabled;

    final inner = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Press scale + tiny rotate for organic feel.
        final scale = 1.0 - _controller.value * 0.05;
        final rotate = _controller.value * 0.012 * (_hover ? 1 : -1);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(scale)
            ..rotateZ(rotate),
          child: child,
        );
      },
      child: SketchyContainer(
        fillColor: enabled
            ? (baseFill)
            : baseFill.withValues(alpha: 0.5),
        strokeColor: ink.withValues(alpha: enabled ? 1.0 : 0.4),
        strokeWidth: widget.strokeWidth,
        borderRadius: widget.borderRadius,
        roughness: widget.roughness,
        padding: widget.padding,
        child: Row(
          mainAxisSize: widget.expand
              ? MainAxisSize.max
              : MainAxisSize.min,
          mainAxisAlignment: widget.expand
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (widget.leadingIcon != null) ...[
              widget.leadingIcon!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily:
                      widget.fontFamily ?? SketchAppFonts.body,
                  fontSize: widget.fontSize,
                  fontWeight:
                      widget.bold ? FontWeight.w700 : FontWeight.w600,
                  color: ink.withValues(alpha: enabled ? 1.0 : 0.4),
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.icon != null) ...[
              const SizedBox(width: 8),
              widget.icon!,
            ],
          ],
        ),
      ),
    );

    final button = MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _tapDown() : null,
        onTapUp: enabled ? (_) => _tapUp() : null,
        onTapCancel: enabled ? _tapUp : null,
        onTap: enabled ? widget.onPressed : null,
        child: widget.expand
            ? SizedBox(width: double.infinity, child: inner)
            : inner,
      ),
    );

    if (!enabled) return button;

    return button
        .animate(
          target: _hover ? 1 : 0,
        )
        .moveY(
          begin: 0,
          end: -2,
          duration: SketchPalette.quick,
          curve: SketchPalette.springSoft,
        );
  }
}

/// Tiny font-name accessor so widgets don't import the theme directly.
class SketchAppFonts {
  SketchAppFonts._();
  static const heading = 'Caveat';
  static const hand = 'PatrickHand';
  static const body = 'Inter';
}
