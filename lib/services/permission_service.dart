import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Tracks the status of every runtime permission OmniCore needs.
///
/// The [PermissionScreen] calls [requestOne] for each permission individually
/// so the REAL OS dialog appears (just like Instagram's camera prompt with
/// "Allow while using the app"). Each tap on a "Grant" button triggers the
/// actual system pop-up.
final permissionServiceProvider =
    NotifierProvider<PermissionService, PermissionState>(PermissionService.new);

@immutable
class PermissionState {
  const PermissionState({
    this.storage = PermissionStatus.permanentlyDenied,
    this.photos = PermissionStatus.permanentlyDenied,
    this.bluetooth = PermissionStatus.permanentlyDenied,
    this.location = PermissionStatus.permanentlyDenied,
    this.notification = PermissionStatus.permanentlyDenied,
    this.requested = false,
  });

  final PermissionStatus storage;
  final PermissionStatus photos;
  final PermissionStatus bluetooth;
  final PermissionStatus location;
  final PermissionStatus notification;
  final bool requested;

  bool get allGranted =>
      _granted(storage) &&
      _granted(photos) &&
      _granted(bluetooth) &&
      _granted(location) &&
      _granted(notification);

  bool _granted(PermissionStatus s) =>
      s == PermissionStatus.granted || s == PermissionStatus.limited;

  bool get anyPermanentlyDenied =>
      storage == PermissionStatus.permanentlyDenied ||
      photos == PermissionStatus.permanentlyDenied ||
      bluetooth == PermissionStatus.permanentlyDenied ||
      location == PermissionStatus.permanentlyDenied ||
      notification == PermissionStatus.permanentlyDenied;

  PermissionState copyWith({
    PermissionStatus? storage,
    PermissionStatus? photos,
    PermissionStatus? bluetooth,
    PermissionStatus? location,
    PermissionStatus? notification,
    bool? requested,
  }) {
    return PermissionState(
      storage: storage ?? this.storage,
      photos: photos ?? this.photos,
      bluetooth: bluetooth ?? this.bluetooth,
      location: location ?? this.location,
      notification: notification ?? this.notification,
      requested: requested ?? this.requested,
    );
  }
}

/// Which permission a tile represents.
enum PermType { storage, photos, bluetooth, location, notification }

class PermissionService extends Notifier<PermissionState> {
  @override
  PermissionState build() {
    // Seed with the current status asynchronously (without requesting).
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshStatuses());
    return const PermissionState();
  }

  /// Re-reads the current permission statuses from the OS WITHOUT requesting.
  /// Use this to refresh the UI after the user returns from system settings.
  Future<void> refreshStatuses() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      state = PermissionState(
        storage: PermissionStatus.granted,
        photos: PermissionStatus.granted,
        bluetooth: PermissionStatus.granted,
        location: PermissionStatus.granted,
        notification: PermissionStatus.granted,
        requested: true,
      );
      return;
    }

    final storage = await Permission.manageExternalStorage.status;
    final photos = await Permission.photos.status;
    final bluetoothConnect = await Permission.bluetoothConnect.status;
    final bluetoothScan = await Permission.bluetoothScan.status;
    final location = await Permission.location.status;
    final notification = await Permission.notification.status;

    // Combine bluetooth permissions: both must be granted/limited
    PermissionStatus bluetooth = PermissionStatus.denied;
    if ((bluetoothConnect == PermissionStatus.granted || bluetoothConnect == PermissionStatus.limited) && 
        (bluetoothScan == PermissionStatus.granted || bluetoothScan == PermissionStatus.limited)) {
        bluetooth = PermissionStatus.granted;
    } else if (bluetoothConnect == PermissionStatus.permanentlyDenied || bluetoothScan == PermissionStatus.permanentlyDenied) {
        bluetooth = PermissionStatus.permanentlyDenied;
    }

    state = PermissionState(
      storage: storage,
      photos: photos,
      bluetooth: bluetooth,
      location: location,
      notification: notification,
      requested: true,
    );
  }

  /// Requests a SINGLE permission — this triggers the REAL OS dialog (the
  /// pop-up with "Allow while using the app" / "Allow only while using the
  /// app" / "Deny" that the user sees in apps like Instagram).
  ///
  /// Returns the new status so the caller can react.
  Future<PermissionStatus> requestOne(PermType type) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return PermissionStatus.granted;
    }

    PermissionStatus status;
    if (type == PermType.bluetooth) {
      final statuses = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
      if ((statuses[Permission.bluetoothConnect] == PermissionStatus.granted || statuses[Permission.bluetoothConnect] == PermissionStatus.limited) && 
          (statuses[Permission.bluetoothScan] == PermissionStatus.granted || statuses[Permission.bluetoothScan] == PermissionStatus.limited)) {
          status = PermissionStatus.granted;
      } else if (statuses[Permission.bluetoothConnect] == PermissionStatus.permanentlyDenied || statuses[Permission.bluetoothScan] == PermissionStatus.permanentlyDenied) {
          status = PermissionStatus.permanentlyDenied;
      } else {
          status = PermissionStatus.denied;
      }
    } else {
      final permission = _toPermission(type);
      status = await permission.request();
    }

    // Update the specific field in state.
    switch (type) {
      case PermType.storage:
        state = state.copyWith(storage: status, requested: true);
        break;
      case PermType.photos:
        state = state.copyWith(photos: status, requested: true);
        break;
      case PermType.bluetooth:
        state = state.copyWith(bluetooth: status, requested: true);
        break;
      case PermType.location:
        state = state.copyWith(location: status, requested: true);
        break;
      case PermType.notification:
        state = state.copyWith(notification: status, requested: true);
        break;
    }
    return status;
  }

  /// Requests ALL permissions one-by-one. Each `request()` call triggers the
  /// real OS dialog sequentially.
  Future<void> requestAll() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      state = PermissionState(
        storage: PermissionStatus.granted,
        photos: PermissionStatus.granted,
        bluetooth: PermissionStatus.granted,
        location: PermissionStatus.granted,
        notification: PermissionStatus.granted,
        requested: true,
      );
      return;
    }

    // Request each one — the OS shows a real pop-up for each.
    final storage = await Permission.manageExternalStorage.request();
    state = state.copyWith(storage: storage, requested: true);

    final photos = await Permission.photos.request();
    state = state.copyWith(photos: photos);

    final btStatuses = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    PermissionStatus bluetooth = PermissionStatus.denied;
    if ((btStatuses[Permission.bluetoothConnect] == PermissionStatus.granted || btStatuses[Permission.bluetoothConnect] == PermissionStatus.limited) && 
        (btStatuses[Permission.bluetoothScan] == PermissionStatus.granted || btStatuses[Permission.bluetoothScan] == PermissionStatus.limited)) {
        bluetooth = PermissionStatus.granted;
    } else if (btStatuses[Permission.bluetoothConnect] == PermissionStatus.permanentlyDenied || btStatuses[Permission.bluetoothScan] == PermissionStatus.permanentlyDenied) {
        bluetooth = PermissionStatus.permanentlyDenied;
    }
    state = state.copyWith(bluetooth: bluetooth);

    final location = await Permission.location.request();
    state = state.copyWith(location: location);

    final notification = await Permission.notification.request();
    state = state.copyWith(notification: notification);
  }

  Permission _toPermission(PermType type) {
    switch (type) {
      case PermType.storage:
        return Permission.manageExternalStorage;
      case PermType.photos:
        return Permission.photos;
      case PermType.bluetooth:
        return Permission.bluetoothConnect; // Handled specially above
      case PermType.location:
        return Permission.location;
      case PermType.notification:
        return Permission.notification;
    }
  }

  /// Opens the system settings page so the user can grant permanently-denied
  /// permissions.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  bool isGranted(PermType type) {
    switch (type) {
      case PermType.storage:
        return state._granted(state.storage);
      case PermType.photos:
        return state._granted(state.photos);
      case PermType.bluetooth:
        return state._granted(state.bluetooth);
      case PermType.location:
        return state._granted(state.location);
      case PermType.notification:
        return state._granted(state.notification);
    }
  }
}
