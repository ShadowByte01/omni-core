import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../database/database.dart';
import '../models/nav_item.dart';

/// Core Riverpod providers shared across the app.
///
/// All providers here are written in plain Riverpod 2.x (no codegen) so the
/// project compiles without running `build_runner`.

/// The single Drift database instance (offline-first).
final dbProvider = Provider<OmniDatabase>((ref) {
  final db = OmniDatabase.open();
  ref.onDispose(() => db.close());
  return db;
});

/// Whether Supabase was configured at launch.
final isSupabaseConfiguredProvider = Provider<bool>((ref) {
  return SupabaseConfig.isConfigured;
});

/// Current navigation destination (kept in memory; not persisted).
final navDestinationProvider =
    StateProvider<NavDestination>((ref) => NavDestination.dashboard);

/// Theme mode preference (paper / chalkboard / system). Persisted locally and,
/// if authenticated, synced to Supabase.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, SketchThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<SketchThemeMode> {
  @override
  SketchThemeMode build() {
    _hydrate();
    return SketchThemeMode.system;
  }

  Future<void> _hydrate() async {
    final db = ref.read(dbProvider);
    final stored = await db.getPref('theme_mode');
    if (stored != null) {
      state = SketchThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => SketchThemeMode.system,
      );
    }
  }

  Future<void> set(SketchThemeMode mode) async {
    state = mode;
    final db = ref.read(dbProvider);
    await db.setPref('theme_mode', mode.name);
  }
}

/// Convenience: the active [NavDestination] with a derived [NavItem].
final currentNavItemProvider = Provider<NavItem>((ref) {
  final dest = ref.watch(navDestinationProvider);
  return NavItem(destination: dest, badge: _badgeFor(ref, dest));
});

int _badgeFor(Ref ref, NavDestination dest) {
  // Show an outbox count badge over the Mail Hub entry when offline emails are
  // queued. (Other destinations return 0 for now.)
  switch (dest) {
    case NavDestination.mail:
      return ref.watch(outboxBadgeProvider);
    default:
      return 0;
  }
}

/// Outbox count used as the Mail nav badge.
final outboxBadgeProvider = StateProvider<int>((ref) => 0);
