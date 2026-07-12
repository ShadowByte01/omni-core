import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/permission_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';

/// Onboarding screen shown on first launch.
///
/// Each "Grant" button triggers the REAL OS permission dialog (the same
/// pop-up Instagram shows for camera access — with "Allow while using the
/// app" / "Only this time" / "Deny"). This is the actual system dialog, not a
/// custom in-app popup.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh statuses and automatically request all permissions sequentially.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(permissionServiceProvider.notifier).refreshStatuses();
      if (mounted) {
        await ref.read(permissionServiceProvider.notifier).requestAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().fadeIn(duration: SketchPalette.smooth).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: SketchPalette.smooth,
                    curve: SketchPalette.springSoft,
                  ),
              const SizedBox(height: 16),
              Text('Set up OmniCore',
                  style: theme.textTheme.displayMedium),
              const SizedBox(height: 6),
              Text(
                'Tap each "Grant" button to allow access. Your phone will show '
                'a real permission pop-up — just like Instagram or WhatsApp.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _PermTile(
                icon: SketchIconType.files,
                title: 'Files & Storage',
                subtitle:
                    'Read your real files from storage for the File Manager.',
                status: perms.storage,
                onGrant: () => _grant(PermType.storage),
              ),
              const SizedBox(height: 12),
              _PermTile(
                icon: SketchIconType.gallery,
                title: 'Photos & Videos',
                subtitle: 'Load your real photo gallery for AI tagging.',
                status: perms.photos,
                onGrant: () => _grant(PermType.photos),
              ),
              const SizedBox(height: 12),
              _PermTile(
                icon: SketchIconType.bluetooth,
                title: 'Bluetooth',
                subtitle: 'Discover real nearby devices for OmniBeam.',
                status: perms.bluetooth,
                onGrant: () => _grant(PermType.bluetooth),
              ),
              const SizedBox(height: 12),
              _PermTile(
                icon: SketchIconType.radar,
                title: 'Location',
                subtitle: 'Required by Android for Bluetooth discovery.',
                status: perms.location,
                onGrant: () => _grant(PermType.location),
              ),
              const SizedBox(height: 12),
              _PermTile(
                icon: SketchIconType.bell,
                title: 'Notifications',
                subtitle: 'Get notified about transfers, mail, and sync.',
                status: perms.notification,
                onGrant: () => _grant(PermType.notification),
              ),
              const SizedBox(height: 28),
              if (perms.anyPermanentlyDenied && perms.requested) ...[
                SketchyContainer(
                  padding: const EdgeInsets.all(14),
                  roughness: 0.8,
                  child: Row(
                    children: [
                      const SketchIcon(SketchIconType.cloudOff, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Some permissions were permanently denied. '
                          'Tap "Open Settings" to grant them manually.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SketchyButton(
                  label: 'Open System Settings',
                  icon: const SketchIcon(SketchIconType.settings, size: 18),
                  expand: true,
                  onPressed: () => ref
                      .read(permissionServiceProvider.notifier)
                      .openSettings(),
                ),
                const SizedBox(height: 14),
              ],
              SketchyButton(
                label: perms.allGranted
                    ? 'Enter OmniCore'
                    : 'Continue to OmniCore',
                icon: const SketchIcon(SketchIconType.check, size: 20),
                fontFamily: 'Caveat',
                fontSize: 26,
                bold: true,
                expand: true,
                onPressed: widget.onDone,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Developed by Xhub · Lostweed by Abhinit',
                  style: TextStyle(
                    fontFamily: 'PatrickHand',
                    fontSize: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Requests a single permission — triggers the REAL OS dialog.
  Future<void> _grant(PermType type) async {
    await ref.read(permissionServiceProvider.notifier).requestOne(type);
    // The state updates via the notifier, UI rebuilds automatically.
  }
}

class _PermTile extends StatelessWidget {
  const _PermTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onGrant,
  });

  final SketchIconType icon;
  final String title;
  final String subtitle;
  final PermissionStatus status;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    final isDark = theme.brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;

    String statusLabel;
    if (granted) {
      statusLabel = 'Granted';
    } else if (status == PermissionStatus.denied) {
      statusLabel = 'Not granted';
    } else if (status == PermissionStatus.permanentlyDenied) {
      statusLabel = 'Permanently denied';
    } else {
      statusLabel = 'Not requested';
    }

    return SketchyContainer(
      fillColor: granted
          ? SketchPalette.accentBlue.withValues(alpha: 0.06)
          : null,
      roughness: 0.8,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SketchIcon(icon, size: 28, color: ink),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: granted
                        ? SketchPalette.accentBlue
                        : ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (granted)
            const SketchIcon(SketchIconType.check, size: 28)
          else
            SketchyButton(
              label: 'Grant',
              icon: const SketchIcon(SketchIconType.plus, size: 16),
              onPressed: onGrant,
            ),
        ],
      ),
    );
  }
}
