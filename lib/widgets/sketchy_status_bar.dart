import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/auth_controller.dart';
import '../controllers/connectivity_controller.dart';
import '../controllers/sync_controller.dart';
import '../models/nav_item.dart';
import '../providers/providers.dart';
import '../services/permission_service.dart';
import '../theme/sketchy_constants.dart';
import 'sketchy_button.dart';
import 'sketchy_card.dart';
import 'sketchy_container.dart';
import 'sketchy_icons.dart';

/// The sketched top status bar: cloud sync icon (left of profile) + profile
/// circle (right). Tapping the cloud triggers a sync; tapping the profile when
/// logged out shows the optional "Login with Google" sheet.
class SketchyStatusBar extends ConsumerWidget {
  const SketchyStatusBar({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final sync = ref.watch(syncControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: theme.textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          // Settings button — opens the settings sheet.
          _IconButton(
            icon: SketchIconType.settings,
            tooltip: 'Settings',
            onTap: () => _showSettingsSheet(context),
          ),
          const SizedBox(width: 10),
          // Cloud sync indicator.
          _CloudButton(
            connectivity: connectivity,
            sync: sync,
            onTap: () => ref.read(syncControllerProvider.notifier).syncNow(),
          ),
          const SizedBox(width: 10),
          // Auth profile circle.
          _ProfileButton(
            auth: auth,
            onTap: () => _showAuthSheet(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SettingsBottomSheet(),
    );
  }

  void _showAuthSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(builder: (context, ref, _) {
          final live = ref.watch(authControllerProvider);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cloud Sync',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  'Auth is optional. OmniCore works fully offline.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                if (live.isAuthenticated) ...[
                  SketchyContainer(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const SketchIcon(SketchIconType.profile, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(live.user?.displayName ?? 'You',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(live.user?.email ?? '',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SketchyButton(
                    label: 'Sign out (go local-only)',
                    icon: const SketchIcon(SketchIconType.close, size: 18),
                    expand: true,
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                      Navigator.of(context).pop();
                    },
                  ),
                ] else ...[
                  SketchyButton(
                    label: 'Login with Google (Optional)',
                    icon: const SketchIcon(SketchIconType.cloud, size: 18),
                    expand: true,
                    disabled: live.status == AuthStatus.localOnly,
                    onPressed: live.status == AuthStatus.localOnly
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                  ),
                  if (live.status == AuthStatus.localOnly) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Cloud sync isn’t configured on this build. '
                      'Add Supabase credentials to enable sign-in.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (live.status == AuthStatus.authenticating) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (live.error != null) ...[
                    const SizedBox(height: 12),
                    Text(live.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontFamily: 'Inter',
                        )),
                  ],
                ],
                const SizedBox(height: 18),
              ],
            ),
          );
        });
      },
    );
  }
}

class _CloudButton extends StatelessWidget {
  const _CloudButton({
    required this.connectivity,
    required this.sync,
    required this.onTap,
  });

  final ConnectivityStatus connectivity;
  final SyncState sync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;

    final bool syncing = sync.status == SyncStatus.syncing;
    final bool online = connectivity == ConnectivityStatus.online;

    SketchIconType icon;
    if (syncing) {
      icon = SketchIconType.cloudSync;
    } else if (online) {
      icon = SketchIconType.cloud;
    } else {
      icon = SketchIconType.cloudOff;
    }

    return Tooltip(
      message: syncing
          ? 'Syncing…'
          : online
              ? 'Online — tap to sync'
              : 'Offline — local only',
      child: SketchyContainer(
        strokeWidth: 1.5,
        borderRadius: 12,
        padding: const EdgeInsets.all(8),
        roughness: 0.8,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 26,
            height: 26,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SketchIcon(icon, size: 24, color: ink),
                if (online && !syncing)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: SketchIcon(SketchIconType.wifi, size: 12, color: ink),
                  ),
              ],
            ),
          )
              .animate(target: syncing ? 1 : 0)
              .rotate(
                begin: 0,
                end: 1,
                duration: const Duration(milliseconds: 900),
                curve: Curves.linear,
              ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.auth, required this.onTap});

  final AuthState auth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return Tooltip(
      message: auth.isAuthenticated
          ? auth.user?.email ?? 'Signed in'
          : 'Not signed in (local only)',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SketchyContainer(
          strokeWidth: 1.5,
          borderRadius: 30,
          padding: const EdgeInsets.all(6),
          roughness: 0.7,
          child: auth.isAuthenticated && auth.user?.photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    auth.user!.photoUrl!,
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SketchIcon(SketchIconType.profile, size: 26),
                  ),
                )
              : SketchIcon(SketchIconType.profile, size: 26, color: ink),
        ),
      ),
    );
  }
}

/// A small sketched icon button used in the status bar.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final SketchIconType icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SketchyContainer(
          strokeWidth: 1.5,
          borderRadius: 12,
          padding: const EdgeInsets.all(8),
          roughness: 0.8,
          child: SketchIcon(icon, size: 22, color: ink),
        ),
      ),
    );
  }
}

/// Settings bottom sheet — shown when tapping the settings icon in the status
/// bar. Contains theme toggle, permission management, and app info.
class _SettingsBottomSheet extends ConsumerWidget {
  const _SettingsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perms = ref.watch(permissionServiceProvider);
    final mode = ref.watch(themeModeProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 0.98,
      builder: (context, controller) {
        return SketchyContainer(
          fillColor: theme.brightness == Brightness.dark
              ? SketchPalette.chalkboard
              : SketchPalette.paperLight,
          roughness: 0.5,
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Settings',
                        style: theme.textTheme.displaySmall),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const SketchIcon(SketchIconType.close, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Theme section.
              Text('Theme', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ThemeChip(
                    label: 'Paper',
                    icon: SketchIconType.gallery,
                    selected: mode == SketchThemeMode.paper,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(SketchThemeMode.paper),
                  ),
                  _ThemeChip(
                    label: 'Chalkboard',
                    icon: SketchIconType.cloudOff,
                    selected: mode == SketchThemeMode.chalkboard,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(SketchThemeMode.chalkboard),
                  ),
                  _ThemeChip(
                    label: 'System',
                    icon: SketchIconType.settings,
                    selected: mode == SketchThemeMode.system,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(SketchThemeMode.system),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Permissions section.
              Text('Permissions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _PermSummaryRow(
                label: 'Files & Storage',
                granted: perms.storage == PermissionStatus.granted,
                onOpen: () => ref
                    .read(permissionServiceProvider.notifier)
                    .openSettings(),
              ),
              _PermSummaryRow(
                label: 'Photos',
                granted: perms.photos == PermissionStatus.granted,
                onOpen: () => ref
                    .read(permissionServiceProvider.notifier)
                    .openSettings(),
              ),
              _PermSummaryRow(
                label: 'Bluetooth',
                granted: perms.bluetooth == PermissionStatus.granted,
                onOpen: () => ref
                    .read(permissionServiceProvider.notifier)
                    .openSettings(),
              ),
              _PermSummaryRow(
                label: 'Location',
                granted: perms.location == PermissionStatus.granted,
                onOpen: () => ref
                    .read(permissionServiceProvider.notifier)
                    .openSettings(),
              ),
              _PermSummaryRow(
                label: 'Notifications',
                granted: perms.notification == PermissionStatus.granted,
                onOpen: () => ref
                    .read(permissionServiceProvider.notifier)
                    .openSettings(),
              ),
              const SizedBox(height: 12),
              SketchyButton(
                label: 'Open System Settings',
                icon: const SketchIcon(SketchIconType.settings, size: 18),
                expand: true,
                onPressed: () => ref
                    .read(permissionServiceProvider.notifier)
                    .openSettings(),
              ),
              const SizedBox(height: 22),

              // About section.
              SketchyCard(
                title: 'About OmniCore',
                icon: SketchIconType.dashboard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OmniCore v1.0',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'The ultimate offline-first, all-in-one software '
                      'ecosystem. Let\'s Sketch theme.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/omni_logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Developed by Xhub',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Lostweed by Abhinit',
                                style: TextStyle(
                                  fontFamily: 'PatrickHand',
                                  fontSize: 15,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final SketchIconType icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SketchyContainer(
        fillColor:
            selected ? ink.withValues(alpha: 0.12) : Colors.transparent,
        strokeColor: selected ? ink : ink.withValues(alpha: 0.3),
        roughness: 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SketchIcon(icon, size: 18, color: ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermSummaryRow extends StatelessWidget {
  const _PermSummaryRow({
    required this.label,
    required this.granted,
    required this.onOpen,
  });

  final String label;
  final bool granted;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          if (granted)
            const SketchIcon(SketchIconType.check, size: 22)
          else
            GestureDetector(
              onTap: onOpen,
              child: const SketchIcon(SketchIconType.settings, size: 22),
            ),
        ],
      ),
    );
  }
}
