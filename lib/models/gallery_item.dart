import 'package:equatable/equatable.dart';

/// A photo on the sketched corkboard gallery.
class GalleryItem extends Equatable {
  const GalleryItem({
    required this.id,
    required this.path,
    required this.capturedAt,
    required this.width,
    required this.height,
    this.tags = const [],
    this.aiState = AiTagState.pending,
    this.rotation = 0,
    this.pinned = true,
  });

  final String id;
  final String path;
  final DateTime capturedAt;
  final int width;
  final int height;
  final List<String> tags;
  final AiTagState aiState;
  final double rotation; // polaroid tilt in radians
  final bool pinned;

  GalleryItem copyWith({
    List<String>? tags,
    AiTagState? aiState,
    double? rotation,
    bool? pinned,
  }) {
    return GalleryItem(
      id: id,
      path: path,
      capturedAt: capturedAt,
      width: width,
      height: height,
      tags: tags ?? this.tags,
      aiState: aiState ?? this.aiState,
      rotation: rotation ?? this.rotation,
      pinned: pinned ?? this.pinned,
    );
  }

  @override
  List<Object?> get props =>
      [id, path, capturedAt, tags, aiState, rotation, pinned];
}

/// On-device AI tagging lifecycle for a gallery item.
enum AiTagState { pending, analyzing, done, failed }

/// A simple system metric snapshot used by the Optimizer dashboard.
class SystemMetrics extends Equatable {
  const SystemMetrics({
    required this.cpuUsage,
    required this.ramUsage,
    required this.ramTotal,
    required this.storageUsed,
    required this.storageTotal,
    required this.batteryLevel,
    required this.thermalState,
    this.sampledAt,
  });

  /// 0.0 - 1.0
  final double cpuUsage;
  final double ramUsage;
  final int ramTotal; // MB
  final double storageUsed;
  final double storageTotal;
  final double batteryLevel; // 0.0 - 1.0
  final ThermalState thermalState;
  final DateTime? sampledAt;

  double get ramUsedMb => ramUsage * ramTotal;
  double get storageFraction =>
      storageTotal == 0 ? 0 : (storageUsed / storageTotal).clamp(0.0, 1.0);

  SystemMetrics copyWith({
    double? cpuUsage,
    double? ramUsage,
    int? ramTotal,
    double? storageUsed,
    double? storageTotal,
    double? batteryLevel,
    ThermalState? thermalState,
    DateTime? sampledAt,
  }) {
    return SystemMetrics(
      cpuUsage: cpuUsage ?? this.cpuUsage,
      ramUsage: ramUsage ?? this.ramUsage,
      ramTotal: ramTotal ?? this.ramTotal,
      storageUsed: storageUsed ?? this.storageUsed,
      storageTotal: storageTotal ?? this.storageTotal,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      thermalState: thermalState ?? this.thermalState,
      sampledAt: sampledAt ?? this.sampledAt,
    );
  }

  @override
  List<Object?> get props => [
        cpuUsage,
        ramUsage,
        ramTotal,
        storageUsed,
        storageTotal,
        batteryLevel,
        thermalState,
      ];
}

enum ThermalState { nominal, fair, serious, critical }

extension ThermalStateX on ThermalState {
  String get label {
    switch (this) {
      case ThermalState.nominal:
        return 'Cool';
      case ThermalState.fair:
        return 'Warm';
      case ThermalState.serious:
        return 'Hot';
      case ThermalState.critical:
        return 'Critical';
    }
  }
}
