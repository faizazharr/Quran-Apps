import 'package:flutter/widgets.dart';

/// Material 3 / common-device-aware breakpoint tokens.
///
/// Use these instead of hard-coding widths so layout decisions are uniform
/// across the codebase.
class Breakpoints {
  Breakpoints._();

  /// 0–599 dp — phones in portrait, foldable inner display closed.
  static const double compact = 600;

  /// 600–839 dp — large phones in landscape, small tablets in portrait.
  static const double medium = 840;

  /// >= 840 dp — tablets in landscape, foldables open, desktops.
  static const double expanded = 1200;

  /// Heights below this are treated as "short" (e.g. phone in landscape) —
  /// the hero header collapses to save vertical space.
  static const double shortHeight = 480;

  /// Cap content width on very wide screens so reading lines stay sensible.
  static const double contentMaxWidth = 720;
}

/// Screen-size classification.
enum ScreenSize { compact, medium, expanded }

/// Snapshot of the relevant `MediaQuery` axes for one build.
class ResponsiveInfo {
  final Size size;
  final Orientation orientation;
  final ScreenSize screenSize;

  const ResponsiveInfo({
    required this.size,
    required this.orientation,
    required this.screenSize,
  });

  factory ResponsiveInfo.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final ScreenSize screen;
    if (w >= Breakpoints.expanded) {
      screen = ScreenSize.expanded;
    } else if (w >= Breakpoints.compact) {
      screen = ScreenSize.medium;
    } else {
      screen = ScreenSize.compact;
    }
    return ResponsiveInfo(
      size: mq.size,
      orientation: mq.orientation,
      screenSize: screen,
    );
  }

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMedium => screenSize == ScreenSize.medium;
  bool get isExpanded => screenSize == ScreenSize.expanded;

  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;

  /// True when there isn't enough vertical room for the full hero header
  /// (e.g. phone held in landscape).
  bool get isShortHeight => size.height < Breakpoints.shortHeight;

  /// Use a side-by-side list/player layout when the screen is wide AND tall
  /// enough. Short-height screens (landscape phone) stay single-column so the
  /// right panel doesn't get crushed vertically.
  /// Requires at least 720 dp so the left content column never drops below ~420 dp.
  bool get useTwoPane => !isShortHeight && size.width >= 720;
}
