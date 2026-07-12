import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_node.dart';
import '../models/nearby_device.dart';
import '../providers/providers.dart';
import '../services/omnibeam_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';

/// OmniBeam — offline peer-to-peer sharing. The user's device is a sketched
/// radio tower at the centre; sketchy radar waves emit to find nearby devices.
/// Drag a sketched file folder onto a dot to beam it — a paper plane flies to
/// the target. All animations use spring physics and run on 120Hz via
/// [AnimatedBuilder] driven by a single [TickerProviderStateMixin].
class OmniBeamScreen extends ConsumerStatefulWidget {
  const OmniBeamScreen({super.key});

  @override
  ConsumerState<OmniBeamScreen> createState() => _OmniBeamScreenState();
}

class _OmniBeamScreenState extends ConsumerState<OmniBeamScreen>
    with TickerProviderStateMixin {
  late final AnimationController _radar;
  final List<_Flight> _flights = [];
  FileNode? _selectedFile;
  List<FileNode> _pickable = const [];

  @override
  void initState() {
    super.initState();
    // Continuous radar sweep. 2s per revolution → smooth at 120Hz.
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Auto-start discovery the first time the screen opens.
      await ref.read(omniBeamServiceProvider.notifier).startDiscovery();
      await _loadPickable();
    });
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  Future<void> _loadPickable() async {
    final db = ref.read(dbProvider);
    final folders = await db.listFiles();
    final files = <FileNode>[];
    for (final f in folders.take(2)) {
      files.addAll(await db.listFiles(parentId: f.id));
    }
    if (!mounted) return;
    setState(() => _pickable = files);
  }

  @override
  Widget build(BuildContext context) {
    final beam = ref.watch(omniBeamServiceProvider);
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Beam it over.',
                  style: Theme.of(context).textTheme.headlineMedium),
              Text(
                'No cables. No cloud. Just radio waves — OmniBeam is free.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Center(
                child: _Radar(
                  radar: _radar,
                  devices: beam.devices,
                  onDrop: _onDrop,
                  flights: _flights,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SketchyButton(
                    label: beam.discovering ? 'Scanning…' : 'Start scan',
                    icon: const SketchIcon(SketchIconType.radar, size: 18),
                    disabled: beam.discovering,
                    onPressed: beam.discovering
                        ? null
                        : () => ref
                            .read(omniBeamServiceProvider.notifier)
                            .startDiscovery(),
                  ),
                  const SizedBox(width: 10),
                  SketchyButton(
                    label: 'Stop',
                    icon: const SketchIcon(SketchIconType.close, size: 18),
                    disabled: !beam.discovering,
                    onPressed: beam.discovering
                        ? () => ref
                            .read(omniBeamServiceProvider.notifier)
                            .stopDiscovery()
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (beam.devices.isEmpty && !beam.discovering)
                Center(
                  child: Text(
                    'Tap "Start scan" to discover real nearby Bluetooth devices.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                )
              else if (beam.devices.isEmpty && beam.discovering)
                Center(
                  child: Text(
                    'Scanning for nearby devices…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                Center(
                  child: Text(
                    '${beam.devices.length} device(s) found.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (beam.error != null) ...[
                const SizedBox(height: 6),
                Text(
                  beam.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontFamily: 'Inter',
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              Text('Pick a file to beam',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _FilePicker(
                files: _pickable,
                selected: _selectedFile,
                onSelect: (f) => setState(() => _selectedFile = f),
              ),
              const SizedBox(height: 18),
              if (beam.transfers.isNotEmpty) ...[
                Text('In flight & history',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final t in beam.transfers.take(6))
                  _TransferRow(transfer: t),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _onDrop(NearbyDevice device) {
    final file = _selectedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a file first, then drag it over.')),
      );
      return;
    }
    // Launch a paper-plane flight animation, then start the real transfer.
    final flight = _Flight(deviceId: device.id);
    setState(() => _flights.add(flight));
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flights.remove(flight));
    });
    ref.read(omniBeamServiceProvider.notifier).sendFile(device.id, file);
  }
}

class _Flight {
  _Flight({required this.deviceId});
  final String deviceId;
}

class _Radar extends StatelessWidget {
  const _Radar({
    required this.radar,
    required this.devices,
    required this.onDrop,
    required this.flights,
  });

  final AnimationController radar;
  final List<NearbyDevice> devices;
  final void Function(NearbyDevice) onDrop;
  final List<_Flight> flights;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = (c.maxWidth).clamp(260.0, 460.0);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radar rings + sweep (120Hz AnimatedBuilder).
              AnimatedBuilder(
                animation: radar,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.square(size),
                    painter: _RadarPainter(
                      sweep: radar.value,
                      isDark:
                          Theme.of(context).brightness == Brightness.dark,
                    ),
                  );
                },
              ),
              // Central radio tower (you).
              const SketchIcon(SketchIconType.radioTower, size: 54),
              // Nearby device dots.
              ..._deviceDots(size),
              // Paper-plane flights overlay.
              ..._flightsOverlay(size),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _deviceDots(double size) {
    final widgets = <Widget>[];
    final center = size / 2;
    for (var i = 0; i < devices.length; i++) {
      final d = devices[i];
      // Angle based on index + id hash so dots spread around the radar.
      final angle =
          (i / math.max(devices.length, 1)) * 2 * math.pi +
          (d.id.hashCode.abs() % 360) * (math.pi / 180) * 0.1;
      final radius = (1 - d.signalStrength) * (center - 46) + 30;
      final dx = center + radius * math.cos(angle);
      final dy = center + radius * math.sin(angle);

      widgets.add(
        Positioned(
          left: dx - 22,
          top: dy - 22,
          child: _DeviceDot(
            device: d,
            onTap: () {},
            onAccept: () => onDrop(d),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _flightsOverlay(double size) {
    final widgets = <Widget>[];
    final center = size / 2;
    for (final flight in flights) {
      final d = devices.firstWhere(
        (dev) => dev.id == flight.deviceId,
        orElse: () => devices.isEmpty
            ? NearbyDevice(
                id: flight.deviceId,
                name: '',
                transport: BeamTransport.webrtc,
                state: BeamDeviceState.beaming,
                signalStrength: 0.5,
              )
            : devices.first,
      );
      final angle = (devices.indexOf(d) / math.max(devices.length, 1)) *
          2 *
          math.pi;
      final radius = (1 - d.signalStrength) * (center - 46) + 30;
      final target = Offset(
        center + radius * math.cos(angle),
        center + radius * math.sin(angle),
      );
      widgets.add(
        _PaperPlane(
          start: Offset(center, center),
          end: target,
        ),
      );
    }
    return widgets;
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.sweep, required this.isDark});
  final double sweep;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2 - 6;

    // Concentric rings.
    final ringPaint = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxR * i / 4, ringPaint);
    }

    // Cross hairs (sketchy).
    final crossPaint = Paint()
      ..color = ink.withValues(alpha: 0.3)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx, 6), Offset(center.dx, size.height - 6),
        crossPaint);
    canvas.drawLine(Offset(6, center.dy), Offset(size.width - 6, center.dy),
        crossPaint);

    // Sweep gradient.
    final sweepAngle = sweep * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: math.pi / 3,
        colors: [
          ink.withValues(alpha: 0.0),
          ink.withValues(alpha: 0.05),
          ink.withValues(alpha: 0.28),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxR),
      0,
      math.pi / 3,
      true,
      sweepPaint,
    );
    canvas.restore();

    // Sweep leading line.
    final lead = Offset(
      center.dx + maxR * math.cos(sweepAngle),
      center.dy + maxR * math.sin(sweepAngle),
    );
    canvas.drawLine(
      center,
      lead,
      Paint()
        ..color = ink.withValues(alpha: 0.7)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweep != sweep || old.isDark != isDark;
}

class _DeviceDot extends StatelessWidget {
  const _DeviceDot({
    required this.device,
    required this.onTap,
    required this.onAccept,
  });
  final NearbyDevice device;
  final VoidCallback onTap;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    final active = device.state == BeamDeviceState.beaming ||
        device.state == BeamDeviceState.connected;
    return DragTarget<_BeamPayload>(
      onAcceptWithDetails: (_) => onAccept(),
      builder: (context, candidate, rejected) {
        final hovered = candidate.isNotEmpty;
        return Tooltip(
          message: '${device.name} · ${device.transport.label}',
          child: GestureDetector(
            onTap: onTap,
            child: SketchyContainer(
              fillColor: hovered
                  ? ink.withValues(alpha: 0.18)
                  : (isDark
                      ? SketchPalette.chalkboardDeep
                      : SketchPalette.paperLight),
              strokeColor: ink,
              strokeWidth: hovered ? 2.2 : 1.6,
              borderRadius: 16,
              roughness: 0.9,
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SketchIcon(
                    device.transport == BeamTransport.bluetooth
                        ? SketchIconType.bluetooth
                        : SketchIconType.device,
                    size: 22,
                    color: ink,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.name,
                    style: TextStyle(
                      fontFamily: 'PatrickHand',
                      fontSize: 11,
                      color: ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (active)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SketchIcon(SketchIconType.paperPlane, size: 14)
                          .animate(onPlay: (c) => c.repeat())
                          .moveX(
                            begin: -4,
                            end: 4,
                            duration: 500.ms,
                          )
                          .then()
                          .moveX(begin: 4, end: -4, duration: 500.ms),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaperPlane extends StatefulWidget {
  const _PaperPlane({required this.start, required this.end});
  final Offset start;
  final Offset end;

  @override
  State<_PaperPlane> createState() => _PaperPlaneState();
}

class _PaperPlaneState extends State<_PaperPlane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final pos = Offset(
          widget.start.dx + (widget.end.dx - widget.start.dx) * t,
          widget.start.dy + (widget.end.dy - widget.start.dy) * t -
              math.sin(t * math.pi) * 40,
        );
        return Positioned(
          left: pos.dx - 16,
          top: pos.dy - 16,
          child: Opacity(
            opacity: 1 - _c.value * 0.3,
            child: const SketchIcon(SketchIconType.paperPlane, size: 32),
          ),
        );
      },
    );
  }
}

class _FilePicker extends StatelessWidget {
  const _FilePicker({
    required this.files,
    required this.selected,
    required this.onSelect,
  });
  final List<FileNode> files;
  final FileNode? selected;
  final void Function(FileNode) onSelect;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No files indexed yet — open the File Manager to seed some.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = files[i];
          final isSel = selected?.id == f.id;
          return Draggable<_BeamPayload>(
            data: _BeamPayload(fileId: f.id),
            feedback: _DragFeedback(name: f.name),
            childWhenDragging: Opacity(
              opacity: 0.4,
              child: _FileChip(file: f, selected: isSel),
            ),
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: _FileChip(file: f, selected: isSel),
            ),
          );
        },
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.file, required this.selected});
  final FileNode file;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return SketchyContainer(
      fillColor: selected
          ? ink.withValues(alpha: 0.12)
          : (isDark
              ? SketchPalette.chalkboardDeep
              : SketchPalette.paperWarm),
      roughness: selected ? 1.1 : 0.8,
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            const SketchIcon(SketchIconType.fileDoc, size: 34),
            const SizedBox(height: 6),
            Text(
              file.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              formatBytes(file.sizeBytes),
              style: TextStyle(
                fontFamily: 'PatrickHand',
                fontSize: 12,
                color: ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SketchyContainer(
        shadow: true,
        roughness: 1.0,
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SketchIcon(SketchIconType.fileDoc, size: 28),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.transfer});
  final BeamTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    final statusLabel = switch (transfer.status) {
      BeamTransferStatus.queued => 'Queued',
      BeamTransferStatus.beaming => 'Beaming…',
      BeamTransferStatus.done => 'Delivered',
      BeamTransferStatus.failed => 'Failed',
      BeamTransferStatus.cancelled => 'Cancelled',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SketchyContainer(
        padding: const EdgeInsets.all(12),
        roughness: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SketchIcon(SketchIconType.paperPlane, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${transfer.fileName} → ${transfer.deviceName}',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(statusLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: transfer.progress,
                minHeight: 8,
                backgroundColor: ink.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(ink),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatBytes(transfer.sentBytes)} / ${formatBytes(transfer.sizeBytes)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BeamPayload {
  const _BeamPayload({required this.fileId});
  final String fileId;
}
