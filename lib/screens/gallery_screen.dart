import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/gallery_item.dart';
import '../providers/providers.dart';
import '../services/ai_tagger.dart';
import '../services/gallery_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';

/// AI-Powered Gallery — a masonry grid of REAL polaroids from the device
/// gallery, pinned to a sketched corkboard. A pulsing brain icon shows AI is
/// analyzing each photo.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  List<GalleryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final galleryState = ref.read(galleryServiceProvider);
    // Load real photos if not already loaded.
    if (!galleryState.permissionGranted && !galleryState.loading) {
      await ref.read(galleryServiceProvider.notifier).loadRealPhotos();
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final db = ref.read(dbProvider);
    final items = await db.listGallery();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryServiceProvider);

    if (_loading || galleryState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!galleryState.permissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SketchIcon(SketchIconType.gallery, size: 64),
              const SizedBox(height: 12),
              Text('Photo permission needed',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                galleryState.error ??
                    'Grant photo access to see your real gallery.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SketchyButton(
                label: 'Grant & Load',
                icon: const SketchIcon(SketchIconType.gallery, size: 18),
                onPressed: () async {
                  await ref
                      .read(galleryServiceProvider.notifier)
                      .loadRealPhotos();
                  await _refresh();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SketchIcon(SketchIconType.gallery, size: 64),
            const SizedBox(height: 12),
            Text('No photos found',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Your device gallery appears to be empty.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(galleryServiceProvider.notifier).loadRealPhotos();
        await _refresh();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SketchIcon(SketchIconType.brain, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Real photos from your gallery — AI tags them on-device.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  SketchyButton(
                    label: 'Refresh',
                    icon: const SketchIcon(SketchIconType.refresh, size: 16),
                    onPressed: () async {
                      await ref
                          .read(galleryServiceProvider.notifier)
                          .loadRealPhotos();
                      await _refresh();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _MasonryBoard(items: _items, onTap: _openEditor),
          ],
        ),
      ),
    );
  }

  void _openEditor(GalleryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditorSheet(item: item, onSaved: _refresh),
    );
  }
}

class _MasonryBoard extends StatelessWidget {
  const _MasonryBoard({required this.items, required this.onTap});
  final List<GalleryItem> items;
  final void Function(GalleryItem) onTap;

  @override
  Widget build(BuildContext context) {
    final cols = <List<GalleryItem>>[[], []];
    for (var i = 0; i < items.length; i++) {
      cols[i % 2].add(items[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(cols[0])),
        const SizedBox(width: 12),
        Expanded(child: _column(cols[1])),
      ],
    );
  }

  Widget _column(List<GalleryItem> col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in col) ...[
          _Polaroid(item: item, onTap: onTap),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.item, required this.onTap});
  final GalleryItem item;
  final void Function(GalleryItem) onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    final analyzing = item.aiState == AiTagState.analyzing ||
        item.aiState == AiTagState.pending;
    final fileExists = File(item.path).existsSync();

    return GestureDetector(
      onTap: () => onTap(item),
      child: Transform.rotate(
        angle: item.rotation,
        child: SketchyContainer(
          shadow: true,
          roughness: 1.0,
          strokeWidth: 1.8,
          padding: const EdgeInsets.all(8),
          fillColor:
              isDark ? SketchPalette.chalkboardDeep : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: fileExists
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              errorBuilder: (_, __, ___) => Container(
                                color: ink.withValues(alpha: 0.08),
                                child: const Center(
                                  child: SketchIcon(SketchIconType.image,
                                      size: 40),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: ink.withValues(alpha: 0.08),
                            child: const Center(
                              child: SketchIcon(SketchIconType.image, size: 40),
                            ),
                          ),
                  ),
                  if (analyzing)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? SketchPalette.chalkboard
                              : SketchPalette.paperLight,
                          shape: BoxShape.circle,
                        ),
                        child: const SketchIcon(SketchIconType.brain, size: 18)
                            .animate(onPlay: (c) => c.repeat())
                            .fadeIn(duration: 450.ms)
                            .then()
                            .fadeOut(duration: 450.ms),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.path.split('/').last,
                style: TextStyle(
                  fontFamily: 'Caveat',
                  fontSize: 22,
                  color: ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in item.tags.take(3))
                    _TagChip(label: tag),
                  if (item.tags.isEmpty && analyzing)
                    const _TagChip(label: 'analyzing…'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return SketchyContainer(
      strokeWidth: 1.2,
      borderRadius: 8,
      roughness: 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PatrickHand',
          fontSize: 13,
          color: ink,
        ),
      ),
    );
  }
}

class _EditorSheet extends ConsumerStatefulWidget {
  const _EditorSheet({required this.item, required this.onSaved});
  final GalleryItem item;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends ConsumerState<_EditorSheet> {
  double _rotation = 0;
  double _brightness = 1.0;
  double _contrast = 1.0;
  bool _drawMode = false;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _rotation = widget.item.rotation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    final fileExists = File(widget.item.path).existsSync();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          color: Colors.transparent,
          child: SketchyContainer(
            fillColor: isDark
                ? SketchPalette.chalkboard
                : SketchPalette.paperLight,
            roughness: 0.6,
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: controller,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Offline Editor',
                          style: theme.textTheme.displaySmall),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const SketchIcon(SketchIconType.close, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Transform.rotate(
                    angle: _rotation,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        _matrix(_brightness, _contrast),
                      ),
                      child: SketchyContainer(
                        padding: const EdgeInsets.all(8),
                        shadow: true,
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: fileExists
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(
                                    File(widget.item.path),
                                    fit: BoxFit.cover,
                                    cacheWidth: 400,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: SketchIcon(SketchIconType.image,
                                          size: 60, color: ink),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: SketchIcon(SketchIconType.image,
                                      size: 60, color: ink),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _toolPalette(theme, ink),
                const SizedBox(height: 14),
                _slider('Brightness', _brightness, (v) {
                  setState(() => _brightness = v);
                }, min: 0.5, max: 1.5),
                _slider('Contrast', _contrast, (v) {
                  setState(() => _contrast = v);
                }, min: 0.5, max: 1.8),
                _slider('Tilt', _rotation, (v) {
                  setState(() => _rotation = v);
                }, min: -0.4, max: 0.4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SketchyButton(
                        label: 'Re-run AI tags',
                        icon: const SketchIcon(SketchIconType.brain, size: 18),
                        onPressed: () {
                          ref
                              .read(aiTaggerProvider.notifier)
                              .reanalyze(widget.item);
                          Navigator.pop(context);
                          widget.onSaved();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SketchyButton(
                        label: 'Save edits',
                        icon: const SketchIcon(SketchIconType.check, size: 18),
                        bold: true,
                        onPressed: () async {
                          final db = ref.read(dbProvider);
                          await db.upsertGallery(widget.item.copyWith(
                            rotation: _rotation,
                          ));
                          if (!mounted) return;
                          Navigator.pop(context);
                          await widget.onSaved();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolPalette(ThemeData theme, Color ink) {
    final tools = <_Tool>[
      _Tool(SketchIconType.crop, 'Crop'),
      _Tool(SketchIconType.filter, 'Filter'),
      _Tool(SketchIconType.draw, 'Draw'),
      _Tool(SketchIconType.erase, 'Erase'),
      _Tool(SketchIconType.pencil, 'Sketch'),
    ];
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = tools[i];
          final active =
              (t.label == 'Draw' && _drawMode) || (_filter == t.label);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (t.label == 'Draw') {
                  _drawMode = !_drawMode;
                } else if (t.label == 'Filter') {
                  _filter = _filter == null ? 'Pencil' : null;
                } else if (t.label == 'Crop') {
                  _rotation = 0;
                }
              });
            },
            child: SketchyContainer(
              fillColor:
                  active ? ink.withValues(alpha: 0.12) : Colors.transparent,
              strokeColor: active ? ink : ink.withValues(alpha: 0.4),
              roughness: 0.8,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  SketchIcon(t.icon, size: 24, color: ink),
                  const SizedBox(height: 4),
                  Text(t.label,
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        fontSize: 13,
                        color: ink,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    void Function(double) onChanged, {
    required double min,
    required double max,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _matrix(double brightness, double contrast) {
    final b = brightness;
    final c = contrast;
    return <double>[
      c, 0, 0, 0, (b - 1) * 255,
      0, c, 0, 0, (b - 1) * 255,
      0, 0, c, 0, (b - 1) * 255,
      0, 0, 0, 1, 0,
    ];
  }
}

class _Tool {
  const _Tool(this.icon, this.label);
  final SketchIconType icon;
  final String label;
}
