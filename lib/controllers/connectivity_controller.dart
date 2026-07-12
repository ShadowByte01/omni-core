import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coarse connectivity state for OmniCore.
enum ConnectivityStatus { online, offline }

/// Tracks device connectivity using `connectivity_plus`. The app is
/// offline-first, so this only affects cloud sync + the sketched cloud icon.
final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
  ConnectivityNotifier.new,
);

class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  ConnectivityStatus build() {
    final conn = Connectivity();
    _sub = conn.onConnectivityChanged.listen((results) {
      state = _reduce(results);
    });
    // Seed with the current value.
    conn.checkConnectivity().then((results) {
      state = _reduce(results);
    });
    ref.onDispose(() => _sub?.cancel());
    return ConnectivityStatus.offline;
  }

  ConnectivityStatus _reduce(List<ConnectivityResult> results) {
    for (final r in results) {
      if (r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet) {
        return ConnectivityStatus.online;
      }
    }
    return ConnectivityStatus.offline;
  }
}
