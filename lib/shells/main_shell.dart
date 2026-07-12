import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/nav_item.dart';
import '../providers/providers.dart';
import '../screens/dashboard_screen.dart';
import '../screens/file_manager_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/mail_hub_screen.dart';
import '../screens/omnibeam_screen.dart';
import '../screens/optimizer_screen.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/paper_background.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_card.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';
import '../widgets/sketchy_status_bar.dart';

/// The persistent responsive shell. Side-rail on Desktop/PC, bottom-nav on
/// Mobile. Wrapped in [RepaintBoundary] so the sketchy chrome never repaints
/// with the active screen's content.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _breakpoint = 820.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(navDestinationProvider);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _breakpoint;
          return PaperBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: isDesktop
                    ? _DesktopLayout(destination: destination)
                    : _MobileLayout(destination: destination),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({required this.destination});
  final NavDestination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _SketchSideRail(destination: destination),
        Expanded(
          child: Column(
            children: [
              SketchyStatusBar(title: destination.label),
              Expanded(child: _ScreenFor(destination: destination)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.destination});
  final NavDestination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SketchyStatusBar(),
        Expanded(child: _ScreenFor(destination: destination)),
        _SketchBottomNav(destination: destination),
      ],
    );
  }
}

class _ScreenFor extends StatelessWidget {
  const _ScreenFor({required this.destination});
  final NavDestination destination;

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps each screen's state alive while switching tabs.
    return IndexedStack(
      index: destination.index,
      children: const [
        DashboardScreen(),
        FileManagerScreen(),
        GalleryScreen(),
        OptimizerScreen(),
        MailHubScreen(),
        OmniBeamScreen(),
      ],
    );
  }
}

class _SketchSideRail extends ConsumerWidget {
  const _SketchSideRail({required this.destination});
  final NavDestination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      width: 224,
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand mark — the OmniCore logo.
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/omni_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text('OmniCore', style: theme.textTheme.displaySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text('Let’s Sketch.',
              style: TextStyle(
                fontFamily: 'PatrickHand',
                fontSize: 16,
                color: theme.textTheme.bodySmall?.color,
              )),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (final d in NavDestination.values)
                  _RailItem(
                    destination: d,
                    selected: d == destination,
                    badge: d == NavDestination.mail
                        ? ref.watch(outboxBadgeProvider)
                        : 0,
                    onTap: () => ref
                        .read(navDestinationProvider.notifier)
                        .state = d,
                  ),
              ],
            ),
          ),
          _RailFooter(),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SketchyContainer(
          fillColor: selected
              ? ink.withValues(alpha: 0.08)
              : Colors.transparent,
          strokeColor: selected ? ink : Colors.transparent,
          strokeWidth: 1.5,
          borderRadius: 14,
          roughness: selected ? 1.0 : 0.4,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              SketchIcon(destination.icon,
                  size: 24, color: ink, wobble: selected ? 1.2 : 0.8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: ink,
                      ),
                    ),
                    Text(
                      destination.handDrawn,
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? SketchPalette.chalkboard
                          : SketchPalette.paperLight,
                    ),
                  ),
                ),
            ],
          ),
        )
            .animate(target: selected ? 1 : 0)
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.02, 1.02),
              duration: SketchPalette.quick,
              curve: SketchPalette.springSoft,
            ),
      ),
    );
  }
}

class _RailFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings button — opens the settings sheet.
          GestureDetector(
            onTap: () => _showSettingsSheet(context, ref),
            behavior: HitTestBehavior.opaque,
            child: SketchyContainer(
              roughness: 0.8,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const SketchIcon(SketchIconType.settings, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'v1.0 · offline-first',
            style: TextStyle(
              fontFamily: 'PatrickHand',
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Developed by Xhub',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          Text(
            'Lostweed by Abhinit',
            style: TextStyle(
              fontFamily: 'PatrickHand',
              fontSize: 12,
              color:
                  theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SettingsSheet(),
    );
  }
}

class _SketchBottomNav extends ConsumerWidget {
  const _SketchBottomNav({required this.destination});
  final NavDestination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: SketchyContainer(
        borderRadius: 20,
        roughness: 0.9,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final d in NavDestination.values)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(navDestinationProvider.notifier)
                      .state = d,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SketchIcon(d.icon,
                            size: 24,
                            color: ink.withValues(
                                alpha: d == destination
                                    ? 1.0
                                    : 0.5),
                            wobble:
                                d == destination ? 1.2 : 0.7),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            d.label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: d == destination
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: ink.withValues(alpha:
                                  d == destination ? 1.0 : 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings sheet — shown when the user taps the settings button in the
/// side-rail footer or the mobile top bar. Contains theme toggle, permission
/// management, and app info.
class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

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
                granted: perms.allGranted
                    ? true
                    : perms.storage == PermissionStatus.granted,
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
