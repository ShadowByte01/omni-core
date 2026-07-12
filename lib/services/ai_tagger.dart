import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/gallery_item.dart';
import '../providers/providers.dart';
import 'ai_service.dart';

/// AI image tagger for the Gallery.
///
/// **Online + NVIDIA key:** uses the NVIDIA NIM vision model to analyse each
/// REAL photo and produce descriptive tags.
/// **Offline / no image file:** uses a deterministic heuristic based on the
/// file name + capture time.
///
/// No fake seeds — only tags real photos that were loaded from the device
/// gallery by the [GalleryService].
final aiTaggerProvider = NotifierProvider<AiTagger, AiTaggerState>(AiTagger.new);

@immutable
class AiTaggerState {
  const AiTaggerState({
    this.usingNvidia = false,
    this.usingFallback = true,
    this.analyzingIds = const {},
  });

  final bool usingNvidia;
  final bool usingFallback;
  final Set<String> analyzingIds;

  AiTaggerState copyWith({
    bool? usingNvidia,
    bool? usingFallback,
    Set<String>? analyzingIds,
  }) {
    return AiTaggerState(
      usingNvidia: usingNvidia ?? this.usingNvidia,
      usingFallback: usingFallback ?? this.usingFallback,
      analyzingIds: analyzingIds ?? this.analyzingIds,
    );
  }
}

class AiTagger extends Notifier<AiTaggerState> {
  Timer? _queueTimer;
  final List<String> _queue = [];
  bool _processing = false;

  @override
  AiTaggerState build() {
    final aiAvailable = ref.read(isAiAvailableProvider);
    _queueTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _drainQueue();
    });
    ref.onDispose(() => _queueTimer?.cancel());
    return AiTaggerState(
      usingNvidia: aiAvailable,
      usingFallback: !aiAvailable,
    );
  }

  /// Queues a REAL gallery item for analysis.
  void enqueue(GalleryItem item) {
    final db = ref.read(dbProvider);
    final analyzing = item.copyWith(aiState: AiTagState.analyzing);
    db.upsertGallery(analyzing);
    _queue.add(item.id);
    state = state.copyWith(
      analyzingIds: {...state.analyzingIds, item.id},
    );
  }

  Future<void> _drainQueue() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;
    try {
      final id = _queue.removeAt(0);
      final db = ref.read(dbProvider);
      final items = await db.listGallery();
      final item = items.firstWhere(
        (g) => g.id == id,
        orElse: () => GalleryItem(
          id: id,
          path: '',
          capturedAt: DateTime.now(),
          width: 0,
          height: 0,
        ),
      );

      final aiAvailable = ref.read(isAiAvailableProvider);
      state = state.copyWith(
        usingNvidia: aiAvailable,
        usingFallback: !aiAvailable,
      );

      List<String> tags;
      if (aiAvailable) {
        final ai = ref.read(nvidiaAiServiceProvider);
        final aiTags = await ai.tagImage(imagePath: item.path);
        tags = aiTags ?? _heuristicTags(item);
      } else {
        tags = _heuristicTags(item);
      }

      final done = item.copyWith(
        tags: tags,
        aiState: AiTagState.done,
      );
      await db.upsertGallery(done);
      final remaining = {...state.analyzingIds}..remove(id);
      state = state.copyWith(analyzingIds: remaining);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('AI tagger drain error: $e');
    } finally {
      _processing = false;
    }
  }

  /// Heuristic fallback driven by file-name keywords + capture time.
  List<String> _heuristicTags(GalleryItem item) {
    final name = item.path.toLowerCase().split('/').last;
    final hour = item.capturedAt.hour;
    final tags = <String>{'photo'};

    const keywordMap = <String, List<String>>{
      'beach': ['beach', 'outdoor', 'summer'],
      'mountain': ['mountain', 'outdoor', 'nature'],
      'forest': ['forest', 'nature', 'green'],
      'tree': ['nature', 'green'],
      'dog': ['pet', 'animal'],
      'cat': ['pet', 'animal'],
      'food': ['food', 'meal'],
      'meal': ['food'],
      'dinner': ['food', 'evening'],
      'lunch': ['food'],
      'coffee': ['drink', 'morning'],
      'sun': ['outdoor', 'sky'],
      'sky': ['sky', 'outdoor'],
      'city': ['city', 'urban'],
      'street': ['urban', 'street'],
      'portrait': ['portrait', 'people'],
      'selfie': ['portrait', 'selfie'],
      'flower': ['nature', 'flower'],
      'snow': ['winter', 'outdoor'],
      'rain': ['weather', 'outdoor'],
      'night': ['night', 'low-light'],
      'concert': ['event', 'music'],
      'travel': ['travel'],
      'family': ['people', 'family'],
      'friend': ['people'],
    };

    keywordMap.forEach((keyword, mapped) {
      if (name.contains(keyword)) tags.addAll(mapped);
    });

    if (hour >= 5 && hour < 10) {
      tags.add('morning');
    } else if (hour >= 10 && hour < 17) {
      tags.add('daytime');
    } else if (hour >= 17 && hour < 20) {
      tags.add('golden-hour');
    } else {
      tags.add('night');
    }

    if (tags.length == 1) {
      final palettes = ['muted', 'warm', 'cool', 'vivid', 'soft'];
      final idx = item.id.hashCode.abs() % palettes.length;
      tags.add(palettes[idx]);
    }

    return tags.take(5).toList();
  }

  /// Re-analyses an item on demand (e.g. after an edit).
  void reanalyze(GalleryItem item) {
    enqueue(item.copyWith(aiState: AiTagState.pending, tags: const []));
  }
}
