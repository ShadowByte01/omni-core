import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/file_node.dart';
import '../providers/providers.dart';
import '../services/file_indexer.dart';
import '../services/permission_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_card.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';
import 'smart_trash_screen.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  final List<FileNode> _stack = [];
  List<FileNode> _contents = [];
  bool _loading = true;
  FileNode? _selected;

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  Future<void> _load(String? absolutePath) async {
    if (!mounted) return;
    setState(() => _loading = true);

    if (absolutePath == null) {
      // Home Screen - Category Shortcuts
      final now = DateTime.now();
      _contents = [
        FileNode(id: 'home:internal', name: 'Internal Storage', path: await ref.read(fileIndexerProvider.notifier).defaultScanRoot(), kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
        FileNode(id: 'home:downloads', name: 'Downloads', path: '/storage/emulated/0/Download', kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
        FileNode(id: 'home:dcim', name: 'Images (DCIM)', path: '/storage/emulated/0/DCIM', kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
        FileNode(id: 'home:pictures', name: 'Pictures', path: '/storage/emulated/0/Pictures', kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
        FileNode(id: 'home:movies', name: 'Videos', path: '/storage/emulated/0/Movies', kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
        FileNode(id: 'home:music', name: 'Audio', path: '/storage/emulated/0/Music', kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
        FileNode(id: 'home:docs', name: 'Documents', path: '/storage/emulated/0/Documents', kind: FileNodeKind.folder, sizeBytes: 0, parentId: null, modifiedAt: now),
      ];
    } else {
      // Load actual directory
      final browser = ref.read(fileIndexerProvider.notifier);
      _contents = await browser.listDirectory(absolutePath);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (_selected != null && !_contents.any((n) => n.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _goBack() async {
    if (_stack.isEmpty) return;
    _stack.removeLast();
    await _load(_stack.isEmpty ? null : _stack.last.path);
  }

  Future<void> _trash(FileNode node) async {
    if (node.id.startsWith('home:')) return;
    final db = ref.read(dbProvider);
    await db.moveToTrash(node);
    await _load(_stack.isEmpty ? null : _stack.last.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Moved ${node.name} to Trash'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 820;
    final indexer = ref.watch(fileIndexerProvider);

    return Column(
      children: [
        _BreadcrumbBar(
          stack: _stack,
          onBack: _goBack,
          onTrash: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SmartTrashScreen()),
          ),
        ),
        Expanded(
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(flex: 3, child: _fileGrid(indexer)),
                    Expanded(
                      flex: 2,
                      child: _detailPane(theme),
                    ),
                  ],
                )
              : _fileGrid(indexer),
        ),
      ],
    );
  }

  Widget _fileGrid(FileBrowserState indexer) {
    if (_loading || indexer.scanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (indexer.scanning)
              Text(
                'Scanning...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      );
    }
    if (_contents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SketchIcon(SketchIconType.folderOpen, size: 64),
              const SizedBox(height: 12),
              Text('This folder is empty.',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 155,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 145,
      ),
      itemCount: _contents.length,
      itemBuilder: (context, i) {
        final node = _contents[i];
        return _FileTile(
          node: node,
          selected: _selected?.id == node.id,
          onTap: () {
            if (node.isFolder) {
              setState(() {
                _stack.add(node);
                _selected = null;
              });
              _load(node.path);
            } else {
              setState(() => _selected = node);
            }
          },
          onLongPress: () {
            if (!node.id.startsWith('home:')) {
              _showActions(node);
            }
          },
        );
      },
    );
  }

  Widget _detailPane(ThemeData theme) {
    final node = _selected;
    if (node == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SketchIcon(SketchIconType.fileDoc, size: 56),
              const SizedBox(height: 10),
              Text('Select a file to preview',
                  style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
      child: SketchyCard(
        title: node.name,
        subtitle: node.kind.label,
        icon: node.isFolder ? SketchIconType.folder : SketchIconType.fileDoc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Size', formatBytes(node.sizeBytes)),
            _detailRow('Modified',
                '${node.modifiedAt.day}/${node.modifiedAt.month}/${node.modifiedAt.year}'),
            _detailRow('Path', node.path),
            if (node.tags.isNotEmpty)
              _detailRow('Tags', node.tags.join(', ')),
            const SizedBox(height: 16),
            if (!node.id.startsWith('home:'))
              Row(
                children: [
                  Expanded(
                    child: SketchyButton(
                      label: 'Move to Trash',
                      icon: const SketchIcon(SketchIconType.trash, size: 18),
                      expand: true,
                      onPressed: () => _trash(node),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showActions(FileNode node) {
    if (node.id.startsWith('home:')) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SketchyButton(
                label: node.isFavorite ? 'Unfavourite' : 'Favourite',
                icon: const SketchIcon(SketchIconType.star, size: 18),
                expand: true,
                onPressed: () async {
                  final db = ref.read(dbProvider);
                  await db.upsertFile(node.copyWith(isFavorite: !node.isFavorite));
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _load(_stack.isEmpty ? null : _stack.last.path);
                },
              ),
              const SizedBox(height: 10),
              SketchyButton(
                label: 'Move to Trash',
                icon: const SketchIcon(SketchIconType.trash, size: 18),
                expand: true,
                onPressed: () {
                  Navigator.pop(context);
                  _trash(node);
                },
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.stack,
    required this.onBack,
    required this.onTrash,
  });

  final List<FileNode> stack;
  final VoidCallback onBack;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          if (stack.isNotEmpty)
            GestureDetector(
              onTap: onBack,
              child: const SketchIcon(SketchIconType.back, size: 26),
            )
          else
            const SizedBox(width: 26),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('Home', style: theme.textTheme.titleMedium),
                  for (final f in stack) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: SketchIcon(SketchIconType.forward, size: 16),
                    ),
                    Text(f.name, style: theme.textTheme.titleMedium),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onTrash,
            child: const Tooltip(
              message: 'Smart Trash',
              child: SketchIcon(SketchIconType.trash, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final FileNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    
    // For Home shortcuts, use a slightly different icon
    final isHomeShortcut = node.id.startsWith('home:');
    final iconType = isHomeShortcut 
        ? SketchIconType.folderOpen 
        : (node.isFolder ? SketchIconType.folder : SketchIconType.fileDoc);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SketchyContainer(
        fillColor: selected
            ? ink.withValues(alpha: 0.08)
            : (isDark ? SketchPalette.chalkboardDeep : SketchPalette.paperWarm),
        roughness: selected ? 1.1 : 0.9,
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FileThumbnail(node: node, fallbackIcon: iconType, ink: ink),
            const SizedBox(height: 8),
            Text(
              node.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
              maxLines: 1, // Fixed text wrapping overlap
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              isHomeShortcut ? 'Storage' : (node.isFolder ? node.kind.label : formatBytes(node.sizeBytes)),
              style: TextStyle(
                fontFamily: 'PatrickHand',
                fontSize: 13,
                color: ink.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (node.isFavorite)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SketchIcon(SketchIconType.starFilled, size: 14),
              ),
          ],
        ),
      )
          .animate(target: selected ? 1 : 0)
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.03, 1.03),
            duration: SketchPalette.quick,
            curve: SketchPalette.springSoft,
          ),
    );
  }
}

class _FileThumbnail extends StatefulWidget {
  const _FileThumbnail({required this.node, required this.fallbackIcon, required this.ink});
  final FileNode node;
  final SketchIconType fallbackIcon;
  final Color ink;

  @override
  State<_FileThumbnail> createState() => _FileThumbnailState();
}

class _FileThumbnailState extends State<_FileThumbnail> {
  Uint8List? _videoThumb;

  @override
  void initState() {
    super.initState();
    if (widget.node.kind == FileNodeKind.video) {
      _loadVideoThumb();
    }
  }

  Future<void> _loadVideoThumb() async {
    try {
      final thumb = await VideoThumbnail.thumbnailData(
        video: widget.node.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 150,
        quality: 50,
      );
      if (mounted) setState(() => _videoThumb = thumb);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.node.kind == FileNodeKind.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(widget.node.path),
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          cacheWidth: 150,
          errorBuilder: (_, __, ___) => SketchIcon(widget.fallbackIcon, size: 46, color: widget.ink),
        ),
      );
    }
    if (widget.node.kind == FileNodeKind.video && _videoThumb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          _videoThumb!,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
        ),
      );
    }
    return SketchIcon(widget.fallbackIcon, size: 46, color: widget.ink);
  }
}



