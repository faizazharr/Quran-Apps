import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// AdMob configuration.
///
/// Safety rules:
/// * Debug/profile builds ALWAYS use Google's test banner unit, whatever is
///   passed in, so developers can never generate invalid traffic on the real
///   ad unit.
/// * Release builds use `--dart-define=ADMOB_BANNER_UNIT_ID=...`. If it is
///   missing, ads are disabled (no banner) rather than silently showing test ads.
///
/// The AdMob *app* ID lives in AndroidManifest.xml and is injected by Gradle
/// (release only) from the `ADMOB_APP_ID` environment variable.
class AdsConfig {
  AdsConfig._();

  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';

  static const _releaseBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
  );

  /// Banner ad unit for the current build mode. Empty means "no ads".
  static String get bannerUnitId =>
      kReleaseMode ? _releaseBannerUnitId : _testBannerAndroid;

  /// Android only (iOS needs GADApplicationIdentifier), and only when a unit
  /// ID is available for this build.
  static bool get supported =>
      !kIsWeb && Platform.isAndroid && bannerUnitId.isNotEmpty;
}
