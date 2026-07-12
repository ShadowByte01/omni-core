import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_node.dart';
import '../providers/providers.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';

/// Smart Trash — a 30-day countdown ring around every deleted file, with
/// swipe-to-restore. All entries live in the local Drift DB and auto-purge
/// after the retention window.
class SmartTrashScreen extends ConsumerStatefulWidget {
  const SmartTrashScreen({super.key});

  @override
  ConsumerState<SmartTrashScreen> createState() => _SmartTrashScreenState();
}

class _SmartTrashScreenState extends ConsumerState<SmartTrashScreen> {
  List<TrashItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final items = await db.listTrash();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _restore(TrashItem item) async {
    final db = ref.read(dbProvider);
    await db.restoreTrash(item.id);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored “${item.name}”.')),
    );
    await _load();
  }

  Future<void> _purge(TrashItem item) async {
    final db = ref.read(dbProvider);
    await db.purgeTrash(item.id);
    HapticFeedback.heavyImpact();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const SketchIcon(SketchIconType.back, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Smart Trash'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SketchIcon(SketchIconType.trash, size: 72),
                      const SizedBox(height: 12),
                      Text('Trash is empty.',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Deleted files rest here for 30 days, then vanish.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SketchIcon(SketchIconType.restore, size: 24),
                              SizedBox(width: 8),
                              Text('Restore'),
                            ],
                          ),
                        ),
                        confirmDismiss: (dir) async {
                          await _restore(item);
                          return false; // we manage the list ourselves
                        },
                        child: SketchyContainer(
                          shadow: true,
                          roughness: 0.9,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _CountdownRing(item: item),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: theme.textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.kind.label} · ${formatBytes(item.sizeBytes)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Deleted ${item.daysRemaining == 0 ? 'today' : '${item.daysRemaining}d left'} · auto-purges in 30d',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Restore',
                                icon: const SketchIcon(
                                    SketchIconType.restore,
                                    size: 22),
                                onPressed: () => _restore(item),
                              ),
                              IconButton(
                                tooltip: 'Delete forever',
                                icon: const SketchIcon(
                                    SketchIconType.delete,
                                    size: 22),
                                onPressed: () => _confirmPurge(item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _confirmPurge(TrashItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text(
          '“${item.name}” can’t be restored after this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          SketchyButton(
            label: 'Delete',
            icon: const SketchIcon(SketchIconType.delete, size: 18),
            onPressed: () {
              Navigator.pop(context);
              _purge(item);
            },
          ),
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.item});
  final TrashItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(56),
            painter: _RingPainter(
              fraction: item.fractionRemaining,
              ink: ink,
            ),
          ),
          Text(
            '${item.daysRemaining}',
            style: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.ink});
  final double fraction;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bg = Paint()
      ..color = ink.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    final fg = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.ink != ink;
}
