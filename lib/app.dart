import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:ui';
import 'models/nav_item.dart';
import 'providers/providers.dart';
import 'screens/permission_screen.dart';
import 'shells/main_shell.dart';
import 'theme/app_theme.dart';

/// Root [MaterialApp] for OmniCore.
///
/// Shows the [PermissionScreen] on first launch so every runtime permission is
/// requested up-front. Once the user taps "Continue", the [MainShell] takes
/// over and every feature loads real device data.
class OmniCoreApp extends ConsumerStatefulWidget {
  const OmniCoreApp({super.key});

  @override
  ConsumerState<OmniCoreApp> createState() => _OmniCoreAppState();
}

class _OmniCoreAppState extends ConsumerState<OmniCoreApp> {
  bool _permissionsDone = false;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'OmniCore',
      debugShowCheckedModeBanner: false,
      theme: SketchAppTheme.light(),
      darkTheme: SketchAppTheme.dark(),
      themeMode: mode.toMaterial(),
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const _SketchScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _permissionsDone
          ? const MainShell()
          : PermissionScreen(
              onDone: () => setState(() => _permissionsDone = true),
            ),
    );
  }
}

/// Encourages 120Hz scrolling + removes the default glow so the sketchy paper
/// stays clean.
class _SketchScrollBehavior extends MaterialScrollBehavior {
  const _SketchScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
