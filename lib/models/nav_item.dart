import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../widgets/sketchy_icons.dart';

/// The six primary navigation destinations in OmniCore.
enum NavDestination {
  dashboard,
  files,
  gallery,
  optimizer,
  mail,
  omnibeam,
}

extension NavDestinationX on NavDestination {
  String get label {
    switch (this) {
      case NavDestination.dashboard:
        return 'Dashboard';
      case NavDestination.files:
        return 'Files';
      case NavDestination.gallery:
        return 'Gallery';
      case NavDestination.optimizer:
        return 'Optimizer';
      case NavDestination.mail:
        return 'Mail Hub';
      case NavDestination.omnibeam:
        return 'OmniBeam';
    }
  }

  SketchIconType get icon {
    switch (this) {
      case NavDestination.dashboard:
        return SketchIconType.dashboard;
      case NavDestination.files:
        return SketchIconType.files;
      case NavDestination.gallery:
        return SketchIconType.gallery;
      case NavDestination.optimizer:
        return SketchIconType.optimizer;
      case NavDestination.mail:
        return SketchIconType.mail;
      case NavDestination.omnibeam:
        return SketchIconType.omnibeam;
    }
  }

  String get handDrawn {
    // Used as the sketchy caption under each rail/bottom-nav item.
    switch (this) {
      case NavDestination.dashboard:
        return 'Home base';
      case NavDestination.files:
        return 'Your filing cabinet';
      case NavDestination.gallery:
        return 'Polaroid wall';
      case NavDestination.optimizer:
        return 'Tune the machine';
      case NavDestination.mail:
        return 'Letter stack';
      case NavDestination.omnibeam:
        return 'Beam it over';
    }
  }
}

/// A descriptor used by the responsive shell to render nav entries.
class NavItem extends Equatable {
  const NavItem({required this.destination, required this.badge});
  final NavDestination destination;
  final int badge;

  @override
  List<Object?> get props => [destination, badge];
}

/// Theme-mode preference, persisted locally and (optionally) synced.
enum SketchThemeMode { paper, chalkboard, system }

extension SketchThemeModeX on SketchThemeMode {
  ThemeMode toMaterial() {
    switch (this) {
      case SketchThemeMode.paper:
        return ThemeMode.light;
      case SketchThemeMode.chalkboard:
        return ThemeMode.dark;
      case SketchThemeMode.system:
        return ThemeMode.system;
    }
  }
}
