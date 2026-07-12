import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sketchy_constants.dart';

/// Hand-drawn doodle-style icon set for OmniCore.
///
/// Every glyph is drawn with a [CustomPainter] using a 1.8px rounded stroke
/// (configurable). This avoids shipping a sprite atlas and keeps icons crisp
/// at any DPI. The slight wobble comes from [SketchRng] so each icon reads as
/// hand-sketched rather than vector-perfect.
class SketchIcon extends StatelessWidget {
  const SketchIcon(
    this.type, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = SketchPalette.strokeRegular,
    this.wobble = 1.0,
  });

  final SketchIconType type;
  final double size;
  final Color? color;
  final double strokeWidth;
  final double wobble;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ??
        (isDark ? SketchPalette.chalkInk : SketchPalette.inkLight);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _DoodlePainter(
          type: type,
          color: c,
          strokeWidth: strokeWidth,
          wobble: wobble,
        ),
      ),
    );
  }
}

enum SketchIconType {
  dashboard,
  files,
  gallery,
  optimizer,
  mail,
  omnibeam,
  trash,
  cloud,
  cloudOff,
  cloudSync,
  profile,
  brain,
  paperPlane,
  broom,
  folder,
  folderOpen,
  fileDoc,
  image,
  star,
  starHalf,
  radioTower,
  radar,
  send,
  inbox,
  outbox,
  refresh,
  settings,
  plus,
  close,
  back,
  forward,
  search,
  check,
  chevronDown,
  menu,
  gauge,
  cpu,
  ram,
  battery,
  clock,
  starFilled,
  download,
  upload,
  share,
  restore,
  delete,
  edit,
  crop,
  filter,
  draw,
  wifi,
  bluetooth,
  device,
  pencil,
  erase,
  tag,
  bell,
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
    required this.wobble,
  });

  final SketchIconType type;
  final Color color;
  final double strokeWidth;
  final double wobble;

  late final Paint _paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  SketchRng _rng(int salt) => SketchRng(salt + type.index * 31);

  Offset _w(Offset p, SketchRng r) =>
      p + sketchWobble(r, wobble * 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // assume square
    final r = _rng(s.toInt());
    void line(Offset a, Offset b) =>
        canvas.drawLine(_w(a, r), _w(b, r), _paint);
    void polyline(List<Offset> pts) {
      for (int i = 1; i < pts.length; i++) {
        canvas.drawLine(_w(pts[i - 1], r), _w(pts[i], r), _paint);
      }
    }

    void arc(Offset center, double radius, double start, double sweep,
        {SketchRng? rng}) {
      final rr = rng ?? r;
      const steps = 14;
      final path = Path();
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final ang = start + sweep * t;
        final pt = _w(
          Offset(
            center.dx + radius * math.cos(ang),
            center.dy + radius * math.sin(ang),
          ),
          rr,
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, _paint);
    }

    void circle(Offset center, double radius, {SketchRng? rng}) {
      arc(center, radius, 0, 2 * math.pi, rng: rng);
    }

    switch (type) {
      case SketchIconType.dashboard:
        // A sketched grid of mini tiles.
        polyline([
          Offset(s * 0.15, s * 0.15),
          Offset(s * 0.15, s * 0.5),
          Offset(s * 0.5, s * 0.5),
          Offset(s * 0.5, s * 0.15),
        ]);
        polyline([
          Offset(s * 0.5, s * 0.5),
          Offset(s * 0.85, s * 0.5),
          Offset(s * 0.85, s * 0.15),
        ]);
        polyline([
          Offset(s * 0.15, s * 0.5),
          Offset(s * 0.15, s * 0.85),
          Offset(s * 0.5, s * 0.85),
        ]);
        polyline([
          Offset(s * 0.5, s * 0.85),
          Offset(s * 0.85, s * 0.85),
          Offset(s * 0.85, s * 0.5),
        ]);
        break;
      case SketchIconType.files:
        polyline([
          Offset(s * 0.2, s * 0.3),
          Offset(s * 0.2, s * 0.82),
          Offset(s * 0.8, s * 0.82),
          Offset(s * 0.8, s * 0.4),
          Offset(s * 0.5, s * 0.4),
          Offset(s * 0.42, s * 0.3),
          Offset(s * 0.2, s * 0.3),
        ]);
        break;
      case SketchIconType.gallery:
        polyline([
          Offset(s * 0.18, s * 0.25),
          Offset(s * 0.82, s * 0.25),
          Offset(s * 0.82, s * 0.78),
          Offset(s * 0.18, s * 0.78),
          Offset(s * 0.18, s * 0.25),
        ]);
        circle(Offset(s * 0.35, s * 0.42), s * 0.06);
        polyline([
          Offset(s * 0.18, s * 0.7),
          Offset(s * 0.45, s * 0.5),
          Offset(s * 0.62, s * 0.64),
          Offset(s * 0.82, s * 0.45),
        ]);
        break;
      case SketchIconType.optimizer:
        circle(Offset(s * 0.5, s * 0.5), s * 0.32);
        circle(Offset(s * 0.5, s * 0.5), s * 0.05);
        line(Offset(s * 0.5, s * 0.5), Offset(s * 0.72, s * 0.32));
        line(Offset(s * 0.5, s * 0.5), Offset(s * 0.5, s * 0.22));
        polyline([
          Offset(s * 0.78, s * 0.18),
          Offset(s * 0.82, s * 0.22),
          Offset(s * 0.78, s * 0.26),
        ]);
        break;
      case SketchIconType.mail:
        polyline([
          Offset(s * 0.18, s * 0.3),
          Offset(s * 0.82, s * 0.3),
          Offset(s * 0.82, s * 0.72),
          Offset(s * 0.18, s * 0.72),
          Offset(s * 0.18, s * 0.3),
        ]);
        polyline([
          Offset(s * 0.18, s * 0.32),
          Offset(s * 0.5, s * 0.55),
          Offset(s * 0.82, s * 0.32),
        ]);
        break;
      case SketchIconType.omnibeam:
      case SketchIconType.radioTower:
        // tower mast + waves.
        line(Offset(s * 0.5, s * 0.85), Offset(s * 0.5, s * 0.3));
        line(Offset(s * 0.5, s * 0.85), Offset(s * 0.32, s * 0.85));
        line(Offset(s * 0.5, s * 0.85), Offset(s * 0.68, s * 0.85));
        polyline([
          Offset(s * 0.36, s * 0.45),
          Offset(s * 0.5, s * 0.3),
          Offset(s * 0.64, s * 0.45),
        ]);
        arc(Offset(s * 0.5, s * 0.32), s * 0.2, -math.pi * 0.85,
            -math.pi * 0.3);
        arc(Offset(s * 0.5, s * 0.32), s * 0.3, -math.pi * 0.85,
            -math.pi * 0.3);
        break;
      case SketchIconType.trash:
        line(Offset(s * 0.28, s * 0.3), Offset(s * 0.28, s * 0.82));
        line(Offset(s * 0.72, s * 0.3), Offset(s * 0.72, s * 0.82));
        polyline([
          Offset(s * 0.28, s * 0.82),
          Offset(s * 0.72, s * 0.82),
        ]);
        polyline([
          Offset(s * 0.22, s * 0.3),
          Offset(s * 0.78, s * 0.3),
        ]);
        polyline([
          Offset(s * 0.4, s * 0.3),
          Offset(s * 0.4, s * 0.22),
          Offset(s * 0.6, s * 0.22),
          Offset(s * 0.6, s * 0.3),
        ]);
        line(Offset(s * 0.4, s * 0.4), Offset(s * 0.4, s * 0.72));
        line(Offset(s * 0.5, s * 0.4), Offset(s * 0.5, s * 0.72));
        line(Offset(s * 0.6, s * 0.4), Offset(s * 0.6, s * 0.72));
        break;
      case SketchIconType.cloud:
        arc(Offset(s * 0.38, s * 0.58), s * 0.16, math.pi, math.pi);
        arc(Offset(s * 0.6, s * 0.58), s * 0.16, math.pi, math.pi);
        polyline([
          Offset(s * 0.22, s * 0.58),
          Offset(s * 0.3, s * 0.45),
          Offset(s * 0.45, s * 0.42),
          Offset(s * 0.58, s * 0.4),
          Offset(s * 0.72, s * 0.45),
          Offset(s * 0.76, s * 0.58),
        ]);
        break;
      case SketchIconType.cloudOff:
        polyline([
          Offset(s * 0.22, s * 0.58),
          Offset(s * 0.3, s * 0.45),
          Offset(s * 0.45, s * 0.42),
          Offset(s * 0.58, s * 0.4),
          Offset(s * 0.72, s * 0.45),
          Offset(s * 0.76, s * 0.58),
          Offset(s * 0.72, s * 0.66),
        ]);
        line(Offset(s * 0.22, s * 0.2), Offset(s * 0.82, s * 0.8));
        break;
      case SketchIconType.cloudSync:
        arc(Offset(s * 0.4, s * 0.58), s * 0.14, math.pi, math.pi);
        polyline([
          Offset(s * 0.26, s * 0.58),
          Offset(s * 0.34, s * 0.46),
          Offset(s * 0.5, s * 0.42),
          Offset(s * 0.66, s * 0.46),
          Offset(s * 0.74, s * 0.58),
        ]);
        arc(Offset(s * 0.5, s * 0.66), s * 0.1, -math.pi * 0.4,
            math.pi * 1.3);
        polyline([
          Offset(s * 0.42, s * 0.58),
          Offset(s * 0.5, s * 0.5),
          Offset(s * 0.58, s * 0.58),
        ]);
        break;
      case SketchIconType.profile:
        circle(Offset(s * 0.5, s * 0.38), s * 0.14);
        arc(Offset(s * 0.5, s * 0.85), s * 0.28, math.pi, math.pi);
        break;
      case SketchIconType.brain:
        circle(Offset(s * 0.5, s * 0.5), s * 0.3);
        line(Offset(s * 0.5, s * 0.22), Offset(s * 0.5, s * 0.78));
        polyline([
          Offset(s * 0.3, s * 0.4),
          Offset(s * 0.4, s * 0.45),
          Offset(s * 0.3, s * 0.5),
        ]);
        polyline([
          Offset(s * 0.7, s * 0.4),
          Offset(s * 0.6, s * 0.45),
          Offset(s * 0.7, s * 0.5),
        ]);
        polyline([
          Offset(s * 0.35, s * 0.62),
          Offset(s * 0.45, s * 0.6),
          Offset(s * 0.5, s * 0.65),
        ]);
        break;
      case SketchIconType.paperPlane:
      case SketchIconType.send:
        polyline([
          Offset(s * 0.2, s * 0.2),
          Offset(s * 0.82, s * 0.5),
          Offset(s * 0.2, s * 0.8),
          Offset(s * 0.35, s * 0.5),
          Offset(s * 0.2, s * 0.2),
        ]);
        line(Offset(s * 0.35, s * 0.5), Offset(s * 0.7, s * 0.5));
        break;
      case SketchIconType.outbox:
        polyline([
          Offset(s * 0.2, s * 0.45),
          Offset(s * 0.5, s * 0.45),
          Offset(s * 0.5, s * 0.2),
        ]);
        polyline([
          Offset(s * 0.18, s * 0.5),
          Offset(s * 0.82, s * 0.5),
          Offset(s * 0.82, s * 0.82),
          Offset(s * 0.18, s * 0.82),
          Offset(s * 0.18, s * 0.5),
        ]);
        break;
      case SketchIconType.inbox:
        polyline([
          Offset(s * 0.18, s * 0.5),
          Offset(s * 0.82, s * 0.5),
          Offset(s * 0.82, s * 0.82),
          Offset(s * 0.18, s * 0.82),
          Offset(s * 0.18, s * 0.5),
        ]);
        polyline([
          Offset(s * 0.5, s * 0.2),
          Offset(s * 0.5, s * 0.55),
          Offset(s * 0.35, s * 0.4),
        ]);
        polyline([Offset(s * 0.5, s * 0.55), Offset(s * 0.65, s * 0.4)]);
        break;
      case SketchIconType.broom:
        polyline([
          Offset(s * 0.68, s * 0.18),
          Offset(s * 0.32, s * 0.6),
        ]);
        polyline([
          Offset(s * 0.22, s * 0.6),
          Offset(s * 0.42, s * 0.8),
          Offset(s * 0.6, s * 0.62),
          Offset(s * 0.4, s * 0.58),
          Offset(s * 0.22, s * 0.6),
        ]);
        for (int i = 0; i < 4; i++) {
          final x = s * 0.28 + i * s * 0.08;
          line(Offset(x, s * 0.6), Offset(x - s * 0.04, s * 0.82));
        }
        break;
      case SketchIconType.folder:
        polyline([
          Offset(s * 0.18, s * 0.34),
          Offset(s * 0.4, s * 0.34),
          Offset(s * 0.48, s * 0.26),
          Offset(s * 0.82, s * 0.26),
          Offset(s * 0.82, s * 0.76),
          Offset(s * 0.18, s * 0.76),
          Offset(s * 0.18, s * 0.34),
        ]);
        break;
      case SketchIconType.folderOpen:
        polyline([
          Offset(s * 0.18, s * 0.36),
          Offset(s * 0.4, s * 0.36),
          Offset(s * 0.48, s * 0.28),
          Offset(s * 0.78, s * 0.28),
        ]);
        polyline([
          Offset(s * 0.18, s * 0.36),
          Offset(s * 0.12, s * 0.78),
          Offset(s * 0.82, s * 0.78),
          Offset(s * 0.86, s * 0.42),
          Offset(s * 0.3, s * 0.42),
        ]);
        break;
      case SketchIconType.fileDoc:
        polyline([
          Offset(s * 0.3, s * 0.18),
          Offset(s * 0.62, s * 0.18),
          Offset(s * 0.74, s * 0.3),
          Offset(s * 0.74, s * 0.82),
          Offset(s * 0.3, s * 0.82),
          Offset(s * 0.3, s * 0.18),
        ]);
        polyline([
          Offset(s * 0.62, s * 0.18),
          Offset(s * 0.62, s * 0.3),
          Offset(s * 0.74, s * 0.3),
        ]);
        line(Offset(s * 0.4, s * 0.46), Offset(s * 0.64, s * 0.46));
        line(Offset(s * 0.4, s * 0.56), Offset(s * 0.64, s * 0.56));
        line(Offset(s * 0.4, s * 0.66), Offset(s * 0.58, s * 0.66));
        break;
      case SketchIconType.image:
        polyline([
          Offset(s * 0.2, s * 0.25),
          Offset(s * 0.8, s * 0.25),
          Offset(s * 0.8, s * 0.78),
          Offset(s * 0.2, s * 0.78),
          Offset(s * 0.2, s * 0.25),
        ]);
        circle(Offset(s * 0.36, s * 0.42), s * 0.05);
        polyline([
          Offset(s * 0.2, s * 0.7),
          Offset(s * 0.45, s * 0.5),
          Offset(s * 0.62, s * 0.64),
          Offset(s * 0.8, s * 0.46),
        ]);
        break;
      case SketchIconType.star:
        _star(canvas, s, false);
        break;
      case SketchIconType.starFilled:
        _star(canvas, s, true);
        break;
      case SketchIconType.starHalf:
        _star(canvas, s, false, half: true);
        break;
      case SketchIconType.radar:
        circle(Offset(s * 0.5, s * 0.5), s * 0.34);
        line(Offset(s * 0.5, s * 0.5), Offset(s * 0.78, s * 0.28));
        circle(Offset(s * 0.5, s * 0.5), s * 0.05);
        arc(Offset(s * 0.5, s * 0.5), s * 0.22, -math.pi / 2, math.pi / 3);
        break;
      case SketchIconType.refresh:
        arc(Offset(s * 0.5, s * 0.5), s * 0.3, -math.pi * 0.7, math.pi * 1.3);
        polyline([
          Offset(s * 0.7, s * 0.22),
          Offset(s * 0.78, s * 0.32),
          Offset(s * 0.66, s * 0.36),
        ]);
        break;
      case SketchIconType.settings:
        // Full hand-drawn gear: outer ring + teeth + inner ring + center hole.
        // Outer ring.
        circle(Offset(s * 0.5, s * 0.5), s * 0.26);
        // Inner ring.
        circle(Offset(s * 0.5, s * 0.5), s * 0.16);
        // Center hole.
        circle(Offset(s * 0.5, s * 0.5), s * 0.06);
        // 8 gear teeth around the outer ring.
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          // Each tooth is a small rectangle pointing outward.
          final innerR = s * 0.26;
          final outerR = s * 0.36;
          final toothW = s * 0.05;
          final cx = s * 0.5;
          final cy = s * 0.5;
          // Tooth corners.
          final p1 = Offset(
              cx + math.cos(a) * innerR - math.sin(a) * toothW,
              cy + math.sin(a) * innerR + math.cos(a) * toothW);
          final p2 = Offset(
              cx + math.cos(a) * innerR + math.sin(a) * toothW,
              cy + math.sin(a) * innerR - math.cos(a) * toothW);
          final p3 = Offset(
              cx + math.cos(a) * outerR + math.sin(a) * toothW,
              cy + math.sin(a) * outerR - math.cos(a) * toothW);
          final p4 = Offset(
              cx + math.cos(a) * outerR - math.sin(a) * toothW,
              cy + math.sin(a) * outerR + math.cos(a) * toothW);
          polyline([p1, p2, p3, p4, p1]);
        }
        break;
      case SketchIconType.plus:
        line(Offset(s * 0.5, s * 0.22), Offset(s * 0.5, s * 0.78));
        line(Offset(s * 0.22, s * 0.5), Offset(s * 0.78, s * 0.5));
        break;
      case SketchIconType.close:
        line(Offset(s * 0.28, s * 0.28), Offset(s * 0.72, s * 0.72));
        line(Offset(s * 0.72, s * 0.28), Offset(s * 0.28, s * 0.72));
        break;
      case SketchIconType.back:
        polyline([
          Offset(s * 0.6, s * 0.25),
          Offset(s * 0.35, s * 0.5),
          Offset(s * 0.6, s * 0.75),
        ]);
        break;
      case SketchIconType.forward:
        polyline([
          Offset(s * 0.4, s * 0.25),
          Offset(s * 0.65, s * 0.5),
          Offset(s * 0.4, s * 0.75),
        ]);
        break;
      case SketchIconType.search:
        circle(Offset(s * 0.42, s * 0.42), s * 0.2);
        line(Offset(s * 0.56, s * 0.56), Offset(s * 0.78, s * 0.78));
        break;
      case SketchIconType.check:
        polyline([
          Offset(s * 0.25, s * 0.52),
          Offset(s * 0.42, s * 0.7),
          Offset(s * 0.78, s * 0.3),
        ]);
        break;
      case SketchIconType.chevronDown:
        polyline([
          Offset(s * 0.28, s * 0.4),
          Offset(s * 0.5, s * 0.64),
          Offset(s * 0.72, s * 0.4),
        ]);
        break;
      case SketchIconType.menu:
        line(Offset(s * 0.24, s * 0.35), Offset(s * 0.76, s * 0.35));
        line(Offset(s * 0.24, s * 0.5), Offset(s * 0.76, s * 0.5));
        line(Offset(s * 0.24, s * 0.65), Offset(s * 0.76, s * 0.65));
        break;
      case SketchIconType.gauge:
        arc(Offset(s * 0.5, s * 0.6), s * 0.32, math.pi, math.pi);
        line(Offset(s * 0.5, s * 0.6), Offset(s * 0.68, s * 0.42));
        circle(Offset(s * 0.5, s * 0.6), s * 0.04);
        break;
      case SketchIconType.cpu:
        polyline([
          Offset(s * 0.32, s * 0.32),
          Offset(s * 0.68, s * 0.32),
          Offset(s * 0.68, s * 0.68),
          Offset(s * 0.32, s * 0.68),
          Offset(s * 0.32, s * 0.32),
        ]);
        polyline([
          Offset(s * 0.42, s * 0.42),
          Offset(s * 0.58, s * 0.42),
          Offset(s * 0.58, s * 0.58),
          Offset(s * 0.42, s * 0.58),
          Offset(s * 0.42, s * 0.42),
        ]);
        for (final x in [0.32, 0.5, 0.68]) {
          line(Offset(s * x, s * 0.22), Offset(s * x, s * 0.32));
          line(Offset(s * x, s * 0.68), Offset(s * x, s * 0.78));
        }
        for (final y in [0.32, 0.5, 0.68]) {
          line(Offset(s * 0.22, s * y), Offset(s * 0.32, s * y));
          line(Offset(s * 0.68, s * y), Offset(s * 0.78, s * y));
        }
        break;
      case SketchIconType.ram:
        polyline([
          Offset(s * 0.18, s * 0.4),
          Offset(s * 0.82, s * 0.4),
          Offset(s * 0.82, s * 0.6),
          Offset(s * 0.72, s * 0.6),
          Offset(s * 0.72, s * 0.7),
          Offset(s * 0.62, s * 0.7),
          Offset(s * 0.62, s * 0.6),
          Offset(s * 0.38, s * 0.6),
          Offset(s * 0.38, s * 0.7),
          Offset(s * 0.28, s * 0.7),
          Offset(s * 0.28, s * 0.6),
          Offset(s * 0.18, s * 0.6),
          Offset(s * 0.18, s * 0.4),
        ]);
        line(Offset(s * 0.3, s * 0.4), Offset(s * 0.3, s * 0.52));
        line(Offset(s * 0.5, s * 0.4), Offset(s * 0.5, s * 0.52));
        line(Offset(s * 0.7, s * 0.4), Offset(s * 0.7, s * 0.52));
        break;
      case SketchIconType.battery:
        polyline([
          Offset(s * 0.2, s * 0.35),
          Offset(s * 0.7, s * 0.35),
          Offset(s * 0.7, s * 0.65),
          Offset(s * 0.2, s * 0.65),
          Offset(s * 0.2, s * 0.35),
        ]);
        line(Offset(s * 0.7, s * 0.43), Offset(s * 0.78, s * 0.43));
        line(Offset(s * 0.7, s * 0.57), Offset(s * 0.78, s * 0.57));
        line(Offset(s * 0.3, s * 0.45), Offset(s * 0.3, s * 0.55));
        line(Offset(s * 0.3, s * 0.5), Offset(s * 0.5, s * 0.5));
        break;
      case SketchIconType.clock:
        circle(Offset(s * 0.5, s * 0.5), s * 0.32);
        line(Offset(s * 0.5, s * 0.5), Offset(s * 0.5, s * 0.3));
        line(Offset(s * 0.5, s * 0.5), Offset(s * 0.64, s * 0.58));
        break;
      case SketchIconType.download:
        line(Offset(s * 0.5, s * 0.22), Offset(s * 0.5, s * 0.6));
        polyline([
          Offset(s * 0.34, s * 0.46),
          Offset(s * 0.5, s * 0.62),
          Offset(s * 0.66, s * 0.46),
        ]);
        polyline([
          Offset(s * 0.24, s * 0.78),
          Offset(s * 0.76, s * 0.78),
        ]);
        break;
      case SketchIconType.upload:
        line(Offset(s * 0.5, s * 0.62), Offset(s * 0.5, s * 0.24));
        polyline([
          Offset(s * 0.34, s * 0.4),
          Offset(s * 0.5, s * 0.24),
          Offset(s * 0.66, s * 0.4),
        ]);
        polyline([
          Offset(s * 0.24, s * 0.78),
          Offset(s * 0.76, s * 0.78),
        ]);
        break;
      case SketchIconType.share:
        circle(Offset(s * 0.3, s * 0.5), s * 0.07);
        circle(Offset(s * 0.7, s * 0.3), s * 0.07);
        circle(Offset(s * 0.7, s * 0.7), s * 0.07);
        line(Offset(s * 0.36, s * 0.46), Offset(s * 0.64, s * 0.34));
        line(Offset(s * 0.36, s * 0.54), Offset(s * 0.64, s * 0.66));
        break;
      case SketchIconType.restore:
        arc(Offset(s * 0.5, s * 0.5), s * 0.28, math.pi * 0.2, math.pi * 1.6);
        polyline([
          Offset(s * 0.36, s * 0.32),
          Offset(s * 0.5, s * 0.32),
          Offset(s * 0.5, s * 0.46),
        ]);
        break;
      case SketchIconType.delete:
        polyline([
          Offset(s * 0.28, s * 0.3),
          Offset(s * 0.72, s * 0.3),
        ]);
        polyline([
          Offset(s * 0.36, s * 0.3),
          Offset(s * 0.4, s * 0.24),
          Offset(s * 0.6, s * 0.24),
          Offset(s * 0.64, s * 0.3),
        ]);
        line(Offset(s * 0.4, s * 0.38), Offset(s * 0.44, s * 0.76));
        line(Offset(s * 0.5, s * 0.38), Offset(s * 0.5, s * 0.76));
        line(Offset(s * 0.6, s * 0.38), Offset(s * 0.56, s * 0.76));
        polyline([Offset(s * 0.36, s * 0.76), Offset(s * 0.64, s * 0.76)]);
        break;
      case SketchIconType.edit:
        polyline([
          Offset(s * 0.62, s * 0.24),
          Offset(s * 0.78, s * 0.4),
        ]);
        polyline([
          Offset(s * 0.28, s * 0.78),
          Offset(s * 0.24, s * 0.82),
          Offset(s * 0.3, s * 0.58),
          Offset(s * 0.62, s * 0.26),
        ]);
        line(Offset(s * 0.3, s * 0.58), Offset(s * 0.46, s * 0.74));
        break;
      case SketchIconType.crop:
        polyline([
          Offset(s * 0.3, s * 0.2),
          Offset(s * 0.3, s * 0.7),
          Offset(s * 0.8, s * 0.7),
        ]);
        polyline([
          Offset(s * 0.2, s * 0.3),
          Offset(s * 0.7, s * 0.3),
          Offset(s * 0.7, s * 0.8),
        ]);
        break;
      case SketchIconType.filter:
        polyline([
          Offset(s * 0.22, s * 0.28),
          Offset(s * 0.78, s * 0.28),
          Offset(s * 0.54, s * 0.56),
          Offset(s * 0.54, s * 0.78),
          Offset(s * 0.46, s * 0.78),
          Offset(s * 0.46, s * 0.56),
          Offset(s * 0.22, s * 0.28),
        ]);
        break;
      case SketchIconType.draw:
        polyline([
          Offset(s * 0.24, s * 0.76),
          Offset(s * 0.4, s * 0.6),
          Offset(s * 0.6, s * 0.3),
          Offset(s * 0.72, s * 0.42),
          Offset(s * 0.5, s * 0.7),
          Offset(s * 0.32, s * 0.8),
          Offset(s * 0.24, s * 0.76),
        ]);
        break;
      case SketchIconType.wifi:
        arc(Offset(s * 0.5, s * 0.78), s * 0.18, -math.pi * 0.85, -math.pi * 0.3);
        arc(Offset(s * 0.5, s * 0.78), s * 0.3, -math.pi * 0.85, -math.pi * 0.3);
        circle(Offset(s * 0.5, s * 0.78), s * 0.03);
        break;
      case SketchIconType.bluetooth:
        polyline([
          Offset(s * 0.4, s * 0.28),
          Offset(s * 0.62, s * 0.5),
          Offset(s * 0.4, s * 0.72),
          Offset(s * 0.4, s * 0.28),
        ]);
        polyline([
          Offset(s * 0.4, s * 0.28),
          Offset(s * 0.62, s * 0.5),
          Offset(s * 0.4, s * 0.72),
        ]);
        line(Offset(s * 0.4, s * 0.5), Offset(s * 0.3, s * 0.4));
        line(Offset(s * 0.4, s * 0.5), Offset(s * 0.3, s * 0.6));
        break;
      case SketchIconType.device:
        polyline([
          Offset(s * 0.28, s * 0.22),
          Offset(s * 0.72, s * 0.22),
          Offset(s * 0.72, s * 0.78),
          Offset(s * 0.28, s * 0.78),
          Offset(s * 0.28, s * 0.22),
        ]);
        line(Offset(s * 0.42, s * 0.68), Offset(s * 0.58, s * 0.68));
        break;
      case SketchIconType.pencil:
        polyline([
          Offset(s * 0.24, s * 0.76),
          Offset(s * 0.28, s * 0.62),
          Offset(s * 0.6, s * 0.3),
          Offset(s * 0.72, s * 0.42),
          Offset(s * 0.4, s * 0.74),
          Offset(s * 0.24, s * 0.76),
        ]);
        line(Offset(s * 0.24, s * 0.76), Offset(s * 0.36, s * 0.64));
        break;
      case SketchIconType.erase:
        polyline([
          Offset(s * 0.3, s * 0.6),
          Offset(s * 0.5, s * 0.4),
          Offset(s * 0.72, s * 0.62),
          Offset(s * 0.52, s * 0.82),
          Offset(s * 0.28, s * 0.82),
          Offset(s * 0.3, s * 0.6),
        ]);
        break;
      case SketchIconType.tag:
        polyline([
          Offset(s * 0.2, s * 0.5),
          Offset(s * 0.5, s * 0.2),
          Offset(s * 0.8, s * 0.5),
          Offset(s * 0.5, s * 0.8),
          Offset(s * 0.2, s * 0.5),
        ]);
        circle(Offset(s * 0.4, s * 0.4), s * 0.04);
        break;
      case SketchIconType.bell:
        // Bell body.
        arc(Offset(s * 0.5, s * 0.42), s * 0.22, math.pi, math.pi);
        line(Offset(s * 0.28, s * 0.42), Offset(s * 0.72, s * 0.42));
        line(Offset(s * 0.3, s * 0.42), Offset(s * 0.3, s * 0.68));
        line(Offset(s * 0.7, s * 0.42), Offset(s * 0.7, s * 0.68));
        arc(Offset(s * 0.5, s * 0.68), s * 0.2, 0, math.pi);
        // Clapper.
        circle(Offset(s * 0.5, s * 0.78), s * 0.05);
        // Top loop.
        arc(Offset(s * 0.5, s * 0.22), s * 0.05, 0, math.pi);
        break;
    }
  }

  void _star(Canvas canvas, double s, bool filled, {bool half = false}) {
    const points = 5;
    final cx = s * 0.5;
    final cy = s * 0.5;
    final outer = s * 0.32;
    final inner = s * 0.14;
    final path = Path();
    final rr = _rng(s.toInt() + 77);
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final pt = _w(Offset(cx + r * math.cos(a), cy + r * math.sin(a)), rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    if (filled) {
      final fill = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fill);
    }
    canvas.drawPath(path, _paint);
    if (half) {
      // erase right half visually by overdrawing with bg-coloured rect
      // (caller is responsible for placing on a known bg).
      final clip = Path()..addRect(Rect.fromPoints(Offset(cx, 0), Offset(s, s)));
      final erasePath = Path.combine(PathOperation.intersect, path, clip);
      canvas.drawPath(
        erasePath,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.type != type ||
      old.wobble != wobble;
}
