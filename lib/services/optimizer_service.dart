import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// System Optimizer service — REAL device metrics.
///
/// * **Battery:** real level from `battery_plus`.
/// * **Storage:** real app data size computed from `path_provider` directories.
/// * **Device info:** real model, CPU cores, OS version from `device_info_plus`.
/// * **SWEEP:** genuinely deletes the app's cache directory and reports real
///   freed bytes.
///
/// No fake animated metrics — everything reflects the actual device state.
final optimizerProvider =
    NotifierProvider<OptimizerService, OptimizerState>(OptimizerService.new);

@immutable
class OptimizerState {
  const OptimizerState({
    this.batteryLevel = 0.5,
    this.appStorageBytes = 0,
    this.cpuCores = 1,
    this.deviceName = '',
    this.osVersion = '',
    this.sweeping = false,
    this.lastFreedMb = 0,
    this.totalFreedMb = 0,
    this.sampledAt,
    this.error,
  });

  /// 0.0 – 1.0 (real, from battery_plus).
  final double batteryLevel;
  /// Real size of the app's data+cache directories in bytes.
  final int appStorageBytes;
  /// Real logical CPU core count (Platform.numberOfProcessors).
  final int cpuCores;
  /// Real device model name.
  final String deviceName;
  /// Real OS version string.
  final String osVersion;
  final bool sweeping;
  final int lastFreedMb;
  final int totalFreedMb;
  final DateTime? sampledAt;
  final String? error;

  double get appStorageMb => appStorageBytes / (1024 * 1024);

  OptimizerState copyWith({
    double? batteryLevel,
    int? appStorageBytes,
    int? cpuCores,
    String? deviceName,
    String? osVersion,
    bool? sweeping,
    int? lastFreedMb,
    int? totalFreedMb,
    DateTime? sampledAt,
    String? error,
  }) {
    return OptimizerState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      appStorageBytes: appStorageBytes ?? this.appStorageBytes,
      cpuCores: cpuCores ?? this.cpuCores,
      deviceName: deviceName ?? this.deviceName,
      osVersion: osVersion ?? this.osVersion,
      sweeping: sweeping ?? this.sweeping,
      lastFreedMb: lastFreedMb ?? this.lastFreedMb,
      totalFreedMb: totalFreedMb ?? this.totalFreedMb,
      sampledAt: sampledAt ?? this.sampledAt,
      error: error,
    );
  }
}

class OptimizerService extends Notifier<OptimizerState> {
  final _battery = Battery();
  Timer? _sampler;

  @override
  OptimizerState build() {
    _sample();
    _sampler = Timer.periodic(const Duration(seconds: 5), (_) => _sample());
    ref.onDispose(() => _sampler?.cancel());
    return const OptimizerState();
  }

  /// Samples real device metrics.
  Future<void> _sample() async {
    try {
      // Real battery level.
      final batteryLevel = await _battery.batteryLevel;

      // Real CPU cores.
      final cpuCores = Platform.numberOfProcessors;

      // Real device info.
      String deviceName = '';
      String osVersion = '';
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceName = '${android.brand} ${android.model}';
        osVersion = 'Android ${android.version.release}';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceName = ios.utsname.machine;
        osVersion = 'iOS ${ios.systemVersion}';
      } else if (Platform.isMacOS) {
        final mac = await deviceInfo.macOsInfo;
        deviceName = mac.model;
        osVersion = 'macOS ${mac.osRelease}';
      } else if (Platform.isWindows) {
        final win = await deviceInfo.windowsInfo;
        deviceName = win.computerName;
        osVersion = 'Windows';
      } else if (Platform.isLinux) {
        final linux = await deviceInfo.linuxInfo;
        deviceName = linux.name;
        osVersion = 'Linux';
      }

      // Real app storage size (scan app data + cache directories).
      final appStorage = await _computeAppStorage();

      state = state.copyWith(
        batteryLevel: batteryLevel / 100.0,
        cpuCores: cpuCores,
        deviceName: deviceName,
        osVersion: osVersion,
        appStorageBytes: appStorage,
        sampledAt: DateTime.now(),
      );
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Computes the real total size of the app's data + cache directories.
  Future<int> _computeAppStorage() async {
    var total = 0;
    try {
      final dirs = <Directory>[
        await getApplicationDocumentsDirectory(),
        await getApplicationSupportDirectory(),
        await getTemporaryDirectory(),
      ];
      if (Platform.isAndroid || Platform.isIOS) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) dirs.add(ext);
      }
      for (final dir in dirs) {
        total += _dirSize(dir);
      }
    } on Exception {
      // ignore — return what we have
    }
    return total;
  }

  int _dirSize(Directory dir) {
    var size = 0;
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          size += entity.statSync().size;
        }
      }
    } on Exception {
      // ignore — permissions may block some subdirs
    }
    return size;
  }

  /// Runs the SWEEP: genuinely deletes the app's cache directory and reports
  /// the real number of freed bytes.
  Future<int> sweep() async {
    state = state.copyWith(sweeping: true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    var freed = 0;
    try {
      final cacheDir = await getTemporaryDirectory();
      freed = _dirSize(cacheDir);
      // Delete the cache directory contents.
      if (cacheDir.existsSync()) {
        for (final entity in cacheDir.listSync(followLinks: false)) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } on Exception {
            // Some files may be locked — skip them.
          }
        }
      }
    } on Exception {
      // ignore
    }

    // Re-sample to get the new (lower) storage size.
    await _sample();

    final freedMb = (freed / (1024 * 1024)).round();
    state = state.copyWith(
      sweeping: false,
      lastFreedMb: freedMb,
      totalFreedMb: state.totalFreedMb + freedMb,
    );
    return freedMb;
  }
}
