import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/animation.dart';

/// Central palette + metrics for the "Let's Sketch" design language.
///
/// The entire aesthetic is strictly Black, White, and shades of Graphite Gray,
/// rendered to look like a hand-drawn pencil sketch on textured paper.
class SketchPalette {
  SketchPalette._();

  // ---- Light (paper) mode ----
  static const Color paperLight = Color(0xFFFAFAFA);
  static const Color paperWarm = Color(0xFFF5F2EA);
  static const Color inkLight = Color(0xFF1A1A1A);
  static const Color graphite1 = Color(0xFF2B2B2B);
  static const Color graphite2 = Color(0xFF4A4A4A);
  static const Color graphite3 = Color(0xFF6E6E6E);
  static const Color graphite4 = Color(0xFF9A9A9A);
  static const Color graphite5 = Color(0xFFC9C9C9);
  static const Color highlighter = Color(0xFFFFF3B0); // faint pencil highlight
  static const Color accentStar = Color(0xFF1A1A1A); // sketched stars are ink

  // ---- Electric blue accent (from the OmniCore logo's glowing hexagon core)
  static const Color accentBlue = Color(0xFF2D9CDB); // electric/cyan-blue
  static const Color accentBlueDim = Color(0xFF1A6FA8);
  static const Color accentBlueGlow = Color(0xFF4FC3F7);

  // ---- Dark (chalkboard) mode ----
  static const Color chalkboard = Color(0xFF101010);
  static const Color chalkboardDeep = Color(0xFF070707);
  static const Color chalkInk = Color(0xFFF2F2F2);
  static const Color chalkSoft = Color(0xFFBFBFBF);
  static const Color chalkDim = Color(0xFF7C7C7C);

  // ---- Stroke defaults ----
  static const double strokeThin = 1.5;
  static const double strokeRegular = 1.8;
  static const double strokeBold = 2.2;

  // ---- Spring curves (120Hz friendly, organic) ----
  static const Curve springCurve = Curves.easeOutBack;
  static const Curve springSoft = Curves.fastOutSlowIn;
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration smooth = Duration(milliseconds: 360);
}

/// Deterministic pseudo-random generator so sketchy wobble is stable
/// across repaints (avoids jitter flicker while keeping a hand-drawn feel).
class SketchRng {
  SketchRng(this.seed);
  final int seed;
  int _state = 0;

  double next({double min = 0.0, double max = 1.0}) {
    _state = (_state * 1103515245 + 12345 + seed) & 0x7fffffff;
    final r = (_state / 0x7fffffff).toDouble();
    return min + r * (max - min);
  }
}

/// Small helper to produce a hand-drawn wobble offset for a point on a path.
Offset sketchWobble(SketchRng rng, double magnitude) {
  return Offset(
    rng.next(min: -magnitude, max: magnitude),
    rng.next(min: -magnitude, max: magnitude),
  );
}

/// Tolerance used by the sketchy painters when flattening curves.
const double sketchTolerance = 0.6;

/// Magic number for the default sketch corner radius.
const double sketchRadius = 14.0;

/// A math clamp helper (kept local to avoid extra imports in widgets).
T sketchClamp<T extends num>(T value, T min, T max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Random seed source combining layout dimensions so a widget redraws
/// consistently for the same size but differs between siblings.
int sketchSeedFor(Size size, {int salt = 7}) {
  return ((size.width.round() * 92821) ^ (size.height.round() * 53017) ^ salt)
      .abs();
}

/// Convert degrees to radians.
double degToRad(double deg) => deg * (math.pi / 180.0);
