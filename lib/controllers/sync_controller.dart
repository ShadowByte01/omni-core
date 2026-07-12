import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../providers/providers.dart';
import 'auth_controller.dart';
import 'connectivity_controller.dart';

/// Cloud-sync lifecycle for the cloud icon in the top status bar.
enum SyncStatus { idle, syncing, synced, error, offline }

@immutable
class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.message,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? message,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message,
    );
  }
}

/// Drives the cloud sync icon. Syncs local user preferences (and file/mail
/// metadata) to Supabase when authenticated AND online. When offline or
/// unauthenticated, reports [SyncStatus.offline] and the app runs purely on
/// the local Drift database.
final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends Notifier<SyncState> {
  Timer? _heartbeat;

  @override
  SyncState build() {
    // React to connectivity + auth changes (fire after build()).
    ref.listen(connectivityProvider, (_, __) => _evaluate());
    ref.listen(authControllerProvider, (_, __) => _evaluate());

    // Periodic re-evaluation so the "last synced" label stays fresh.
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _evaluate());
    ref.onDispose(() => _heartbeat?.cancel());
    // Return the computed initial state (do not set `state` inside build()).
    return _computeInitial();
  }

  SyncState _computeInitial() {
    final connected =
        ref.read(connectivityProvider) == ConnectivityStatus.online;
    final auth = ref.read(authControllerProvider);
    if (!connected || !auth.isAuthenticated) {
      return const SyncState(status: SyncStatus.offline);
    }
    return const SyncState(status: SyncStatus.idle);
  }

  void _evaluate() {
    final connected =
        ref.read(connectivityProvider) == ConnectivityStatus.online;
    final auth = ref.read(authControllerProvider);
    if (!connected || !auth.isAuthenticated) {
      state = SyncState(
        status: SyncStatus.offline,
        lastSyncedAt: state.lastSyncedAt,
      );
      return;
    }
    state = state.copyWith(status: SyncStatus.idle);
  }

  /// Push local preferences to the cloud. Called when the user edits prefs or
  /// taps the cloud icon.
  Future<void> syncNow() async {
    final connected = ref.read(connectivityProvider) == ConnectivityStatus.online;
    final auth = ref.read(authControllerProvider);
    if (!SupabaseConfig.isConfigured ||
        !connected ||
        !auth.isAuthenticated) {
      state = SyncState(
        status: SyncStatus.offline,
        lastSyncedAt: state.lastSyncedAt,
        message: 'Offline or not signed in — keeping local data only.',
      );
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing, message: 'Syncing…');
    try {
      final db = ref.read(dbProvider);
      final client = Supabase.instance.client;
      final userId = auth.user!.id;
      final prefs = await db.allPrefs();

      // Upsert each preference into the `user_preferences` Postgres table.
      if (prefs.isNotEmpty) {
        final rows = prefs.entries
            .map((e) => {
                  'user_id': userId,
                  'key': e.key,
                  'value': e.value,
                })
            .toList();
        await client.from('user_preferences').upsert(
              rows,
              onConflict: 'user_id,key',
            );
      }

      state = SyncState(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
        message: 'All caught up.',
      );
    } on PostgrestException catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        lastSyncedAt: state.lastSyncedAt,
        message: e.message,
      );
    } on Exception catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        lastSyncedAt: state.lastSyncedAt,
        message: e.toString(),
      );
    }
  }
}
