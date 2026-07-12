import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../models/file_node.dart';
import '../providers/providers.dart';

final fileIndexerProvider =
    NotifierProvider<FileBrowser, FileBrowserState>(FileBrowser.new);

@immutable
class FileBrowserState {
  const FileBrowserState({
    this.scanning = false,
    this.lastScannedPath,
    this.indexedCount = 0,
    this.error,
  });

  final bool scanning;
  final String? lastScannedPath;
  final int indexedCount;
  final String? error;

  FileBrowserState copyWith({
    bool? scanning,
    String? lastScannedPath,
    int? indexedCount,
    String? error,
  }) {
    return FileBrowserState(
      scanning: scanning ?? this.scanning,
      lastScannedPath: lastScannedPath ?? this.lastScannedPath,
      indexedCount: indexedCount ?? this.indexedCount,
      error: error,
    );
  }
}

class FileBrowser extends Notifier<FileBrowserState> {
  @override
  FileBrowserState build() {
    return const FileBrowserState();
  }
  
  Future<String> defaultScanRoot() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final path = dir.path;
        final split = path.split('Android');
        if (split.isNotEmpty && split[0].isNotEmpty) {
          var root = split[0];
          if (root.endsWith('/')) root = root.substring(0, root.length - 1);
          return root;
        }
      }
      return '/storage/emulated/0';
    }
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return home;
  }

  Future<void> scanDirectory(String rootPath) async {
    // No-op for backwards compatibility with UI
  }

  /// Lists the contents of a directory dynamically and merges DB metadata.
  Future<List<FileNode>> listDirectory(String rootPath) async {
    final root = Directory(rootPath);
    if (!root.existsSync()) return [];

    final db = ref.read(dbProvider);
    final dbNodes = await db.listFiles(parentId: rootPath);
    final dbMap = {for (final n in dbNodes) n.id: n};

    final trashItems = await db.listTrash();
    final trashPaths = trashItems.map((t) => t.path).toSet();

    final List<FileNode> nodes = [];
    try {
      await for (final entity in root.list(followLinks: false)) {
        try {
          final name = p.basename(entity.path);
          if (name.startsWith('.')) continue; // skip hidden
          if (trashPaths.contains(entity.path)) continue; // skip trashed

          final id = entity.path;
          final dbNode = dbMap[id];
          
          if (entity is Directory) {
            final stat = entity.statSync();
            nodes.add(FileNode(
              id: id,
              name: name,
              path: entity.path,
              kind: FileNodeKind.folder,
              sizeBytes: 0,
              parentId: rootPath,
              modifiedAt: stat.modified,
              isFavorite: dbNode?.isFavorite ?? false,
              tags: dbNode?.tags ?? const [],
            ));
          } else if (entity is File) {
            final stat = entity.statSync();
            nodes.add(FileNode(
              id: id,
              name: name,
              path: entity.path,
              kind: _kindFor(entity.path),
              sizeBytes: stat.size,
              parentId: rootPath,
              modifiedAt: stat.modified,
              isFavorite: dbNode?.isFavorite ?? false,
              tags: dbNode?.tags ?? const [],
            ));
          }
        } catch (_) {
          // ignore individual file permission errors
        }
      }
    } catch (_) {
      // ignore root permission denied
    }

    nodes.sort((a, b) {
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return nodes;
  }

  FileNodeKind _kindFor(String path) {
    final mime = lookupMimeType(path);
    if (mime == null) return FileNodeKind.other;
    if (mime.startsWith('image/')) return FileNodeKind.image;
    if (mime.startsWith('audio/')) return FileNodeKind.audio;
    if (mime.startsWith('video/')) return FileNodeKind.video;
    if (mime == 'application/pdf' || mime.contains('word') ||
        mime.contains('sheet') || mime == 'text/plain' ||
        mime == 'text/csv' || mime.contains('json') || mime.contains('xml')) {
      return FileNodeKind.document;
    }
    if (mime.contains('zip') || mime.contains('compressed') ||
        mime.contains('tar') || mime.contains('rar') || mime.contains('7z')) {
      return FileNodeKind.archive;
    }
    return FileNodeKind.other;
  }
}
