import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// AdMob configuration.
///
/// Defaults are Google's public *test* ad unit IDs, so debug builds and fresh
/// clones never serve real ads. Release builds must pass the real ID:
///
/// ```sh
/// flutter build appbundle \
///   --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-XXXX/YYYY
/// ```
///
/// The AdMob *app* ID lives in AndroidManifest.xml (`com.google.android.gms.ads.APPLICATION_ID`).
class AdsConfig {
  AdsConfig._();

  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';

  static const bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: _testBannerAndroid,
  );

  /// Ads are wired for Android only (iOS needs GADApplicationIdentifier).
  static bool get supported => !kIsWeb && Platform.isAndroid;
}
