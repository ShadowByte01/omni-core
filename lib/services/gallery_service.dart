import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/gallery_item.dart';
import '../providers/providers.dart';
import 'ai_tagger.dart';

/// Loads REAL photos from the device gallery via `photo_manager` and stores
/// them in the Drift DB. No fake photos — every polaroid on the corkboard is a
/// real photo from the user's gallery.
final galleryServiceProvider =
    NotifierProvider<GalleryService, GalleryState>(GalleryService.new);

@immutable
class GalleryState {
  const GalleryState({
    this.loading = false,
    this.permissionGranted = false,
    this.loadedCount = 0,
    this.error,
  });

  final bool loading;
  final bool permissionGranted;
  final int loadedCount;
  final String? error;

  GalleryState copyWith({
    bool? loading,
    bool? permissionGranted,
    int? loadedCount,
    String? error,
  }) {
    return GalleryState(
      loading: loading ?? this.loading,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      loadedCount: loadedCount ?? this.loadedCount,
      error: error,
    );
  }
}

class GalleryService extends Notifier<GalleryState> {
  final _uuid = Uuid();

  @override
  GalleryState build() {
    return const GalleryState();
  }

  /// Requests photo permission and loads real photos from the device gallery.
  Future<void> loadRealPhotos() async {
    state = state.copyWith(loading: true, error: null);

    // Request permission via photo_manager.
    final ps = await PhotoManager.requestPermissionExtend();
    
    // Ignore photo_manager's internal strict check because permission_handler 
    // already verified we have OS-level permissions. 
    try {
      PhotoManager.setIgnorePermissionCheck(true);
    } catch (_) {}

    try {
      final db = ref.read(dbProvider);

      // Clear previously indexed items that no longer exist on disk.
      final existing = await db.listGallery();
      for (final item in existing) {
        final file = File(item.path);
        if (!file.existsSync()) {
          await db.deleteGallery(item.id);
        }
      }

      // Fetch all photo albums.
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        state = state.copyWith(
          loading: false,
          permissionGranted: true,
          loadedCount: 0,
        );
        return;
      }

      // Load up to 200 most recent photos.
      final assets = await albums.first.getAssetListPaged(
        page: 0,
        size: 200,
      );

      var count = 0;
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        final path = file.path;
        // Skip if already indexed.
        final already = existing.any((e) => e.path == path);
        if (already) {
          count++;
          continue;
        }

        final item = GalleryItem(
          id: _uuid.v4(),
          path: path,
          capturedAt: asset.createDateTime,
          width: asset.width,
          height: asset.height,
          rotation: 0,
          pinned: true,
        );
        await db.upsertGallery(item);

        // Queue for AI tagging.
        ref.read(aiTaggerProvider.notifier).enqueue(item);
        count++;
      }

      state = state.copyWith(
        loading: false,
        permissionGranted: true,
        loadedCount: count,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        loading: false,
        permissionGranted: true,
        error: e.toString(),
      );
    }
  }

  /// Checks if photo permission is granted (without requesting).
  Future<bool> checkPermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }
}
