import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/connectivity_controller.dart';
import '../models/file_node.dart';
import '../models/gallery_item.dart' show AiTagState;
import '../models/nav_item.dart';
import '../providers/providers.dart';
import '../services/ai_tagger.dart';
import '../services/file_indexer.dart';
import '../services/mail_service.dart';
import '../services/optimizer_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_card.dart';
import '../widgets/sketchy_icons.dart';

/// The Dashboard — a sketched overview of the whole workspace with quick
/// actions and live stat cards.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger the real file indexer to scan the device on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fileIndexerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectivity = ref.watch(connectivityProvider);
    final optimizer = ref.watch(optimizerProvider);
    final mail = ref.watch(mailServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good to see you.', style: theme.textTheme.displayMedium)
              .animate()
              .fadeIn(duration: SketchPalette.smooth)
              .slideY(begin: 0.1, end: 0),
          Text(
            connectivity == ConnectivityStatus.online
                ? 'You’re online — cloud sync is ready.'
                : 'You’re offline — everything still works. Sketch on.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          // Quick actions row.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickAction(
                icon: SketchIconType.files,
                label: 'Files',
                onTap: () => _go(NavDestination.files),
              ),
              _QuickAction(
                icon: SketchIconType.gallery,
                label: 'Gallery',
                onTap: () => _go(NavDestination.gallery),
              ),
              _QuickAction(
                icon: SketchIconType.broom,
                label: 'Sweep RAM',
                onTap: () => _go(NavDestination.optimizer),
              ),
              _QuickAction(
                icon: SketchIconType.paperPlane,
                label: 'Beam',
                onTap: () => _go(NavDestination.omnibeam),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // Stat grid.
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 720 ? 3 : (c.maxWidth > 420 ? 2 : 1);
              return _StatGrid(
                cols: cols,
                stats: [
                  _Stat(
                    icon: SketchIconType.battery,
                    title: 'Battery',
                    value: '${(optimizer.batteryLevel * 100).round()}%',
                    sub: optimizer.deviceName.isNotEmpty
                        ? optimizer.deviceName
                        : 'Device',
                  ),
                  _Stat(
                    icon: SketchIconType.folder,
                    title: 'App storage',
                    value: '${optimizer.appStorageMb.toStringAsFixed(1)} MB',
                    sub: '${optimizer.cpuCores} CPU cores · ${optimizer.osVersion}',
                  ),
                  _Stat(
                    icon: SketchIconType.mail,
                    title: 'Inbox',
                    value: '${mail.inbox.length}',
                    sub: mail.outbox.isEmpty
                        ? 'Outbox clear'
                        : '${mail.outbox.length} queued to fly',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          SketchyCard(
            title: 'Recent files',
            icon: SketchIconType.folder,
            trailing: SketchyButton(
              label: 'Open',
              icon: const SketchIcon(SketchIconType.forward, size: 16),
              onPressed: () => _go(NavDestination.files),
            ),
            child: const _RecentFiles(),
          ),
          const SizedBox(height: 16),
          SketchyCard(
            title: 'On the corkboard',
            icon: SketchIconType.gallery,
            trailing: SketchyButton(
              label: 'Open',
              icon: const SketchIcon(SketchIconType.forward, size: 16),
              onPressed: () => _go(NavDestination.gallery),
            ),
            child: const _RecentGalleryStrip(),
          ),
        ],
      ),
    );
  }

  void _go(NavDestination d) {
    ref.read(navDestinationProvider.notifier).state = d;
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final SketchIconType icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return SketchyButton(
      label: label,
      leadingIcon: null,
      icon: SketchIcon(icon, size: 18, color: ink),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      fontFamily: 'PatrickHand',
      fontSize: 17,
      onPressed: onTap,
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cols, required this.stats});
  final int cols;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in stats)
          SizedBox(
            width: (MediaQuery.of(context).size.width / cols - 12)
                .clamp(160.0, 320.0),
            child: s,
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
  });
  final SketchIconType icon;
  final String title;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SketchyCard(
      icon: icon,
      title: title,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.displaySmall),
            const SizedBox(height: 2),
            Text(sub, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecentFiles extends ConsumerWidget {
  const _RecentFiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(_recentFilesProvider);
    return files.when(
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No files indexed yet.'),
          );
        }
        return Column(
          children: [
            for (final f in list.take(4)) _FileRow(node: f),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

final _recentFilesProvider = FutureProvider.autoDispose<List<FileNode>>((ref) async {
  final db = ref.watch(dbProvider);
  final folders = await db.listFiles();
  final all = <FileNode>[];
  for (final folder in folders.take(3)) {
    final children = await db.listFiles(parentId: folder.id);
    all.addAll(children);
  }
  all.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  return all;
});

class _FileRow extends StatelessWidget {
  const _FileRow({required this.node});
  final FileNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SketchIcon(
            node.isFolder ? SketchIconType.folder : SketchIconType.fileDoc,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(node.name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(formatBytes(node.sizeBytes),
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RecentGalleryStrip extends ConsumerWidget {
  const _RecentGalleryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_recentGalleryProvider);
    return items.when(
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Corkboard is empty.'),
          );
        }
        return SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = list[i];
              return _PolaroidThumb(item: g);
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

final _recentGalleryProvider =
    FutureProvider.autoDispose<List<GalleryThumb>>((ref) async {
  final db = ref.watch(dbProvider);
  final items = await db.listGallery();
  return items
      .take(8)
      .map((g) => GalleryThumb(
            id: g.id,
            name: g.path.split('/').last,
            tags: g.tags,
            analyzing: g.aiState == AiTagState.analyzing ||
                g.aiState == AiTagState.pending,
          ))
      .toList();
});

class GalleryThumb {
  const GalleryThumb({
    required this.id,
    required this.name,
    required this.tags,
    required this.analyzing,
  });
  final String id;
  final String name;
  final List<String> tags;
  final bool analyzing;
}

class _PolaroidThumb extends StatelessWidget {
  const _PolaroidThumb({required this.item});
  final GalleryThumb item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Stack(
            children: [
              SketchyCard(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 56,
                  height: 56,
                  color: ink.withValues(alpha: 0.08),
                  child: const SketchIcon(SketchIconType.image, size: 28),
                ),
              ),
              if (item.analyzing)
                Positioned(
                  right: -2,
                  top: -2,
                  child: const SketchIcon(SketchIconType.brain, size: 16)
                      .animate(onPlay: (c) => c.repeat())
                      .fadeIn(duration: 400.ms)
                      .then()
                      .fadeOut(duration: 400.ms),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: TextStyle(
              fontFamily: 'PatrickHand',
              fontSize: 12,
              color: ink.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
