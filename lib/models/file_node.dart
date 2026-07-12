import 'package:equatable/equatable.dart';

/// Kind of a file-system node for the File Manager.
enum FileNodeKind { folder, document, image, audio, video, archive, other }

extension FileNodeKindX on FileNodeKind {
  String get label {
    switch (this) {
      case FileNodeKind.folder:
        return 'Folder';
      case FileNodeKind.document:
        return 'Document';
      case FileNodeKind.image:
        return 'Image';
      case FileNodeKind.audio:
        return 'Audio';
      case FileNodeKind.video:
        return 'Video';
      case FileNodeKind.archive:
        return 'Archive';
      case FileNodeKind.other:
        return 'File';
    }
  }
}

/// A single node in the local file index (offline-first, Drift-backed).
class FileNode extends Equatable {
  const FileNode({
    required this.id,
    required this.name,
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.parentId,
    required this.modifiedAt,
    this.isFavorite = false,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String path;
  final FileNodeKind kind;
  final int sizeBytes;
  final String? parentId;
  final DateTime modifiedAt;
  final bool isFavorite;
  final List<String> tags;

  bool get isFolder => kind == FileNodeKind.folder;

  FileNode copyWith({
    String? name,
    int? sizeBytes,
    DateTime? modifiedAt,
    bool? isFavorite,
    List<String>? tags,
  }) {
    return FileNode(
      id: id,
      name: name ?? this.name,
      path: path,
      kind: kind,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      parentId: parentId,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, path, kind, sizeBytes, parentId, modifiedAt, isFavorite, tags];
}

/// A trashed file with a 30-day countdown.
class TrashItem extends Equatable {
  const TrashItem({
    required this.id,
    required this.fileId,
    required this.name,
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.deletedAt,
    this.restoredPath,
  });

  final String id;
  final String fileId;
  final String name;
  final String path;
  final FileNodeKind kind;
  final int sizeBytes;
  final DateTime deletedAt;
  final String? restoredPath;

  /// Smart Trash retention window.
  static const Duration retention = Duration(days: 30);

  DateTime get expiresAt => deletedAt.add(retention);

  int get daysRemaining =>
      expiresAt.difference(DateTime.now()).inDays.clamp(0, 30);

  double get fractionRemaining {
    final total = retention.inMilliseconds;
    final elapsed = DateTime.now().difference(deletedAt).inMilliseconds;
    return (1 - elapsed / total).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props =>
      [id, fileId, name, path, kind, sizeBytes, deletedAt, restoredPath];
}

/// Helper to format byte sizes in a sketchy, human-readable way.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (bytes > 0)
      ? (bytes.bitLength - 1) ~/ 10
      : 0;
  final idx = i.clamp(0, units.length - 1);
  final value = bytes / (1 << (idx * 10));
  return '${value.toStringAsFixed(idx == 0 ? 0 : 1)} ${units[idx]}';
}
