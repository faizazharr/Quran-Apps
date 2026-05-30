import 'package:flutter/foundation.dart';

/// Build flavours the app can run in.
enum AppFlavor { dev, staging, prod }

/// Single source of truth for environment-driven configuration.
///
/// Values are populated from `--dart-define` at compile time so secrets and
/// per-environment URLs never live in the codebase or git history. Example:
///
/// ```sh
/// flutter run \
///   --dart-define=APP_FLAVOR=staging \
///   --dart-define=API_BASE_URL=https://staging.api.alquran.cloud/v1
/// ```
///
/// Hardcoded defaults intentionally point at the public production endpoints
/// so the app still works for fresh clones without any flags.
class AppConfig {
  final AppFlavor flavor;
  final String apiBaseUrl;
  final String audioCdnBaseUrl;
  final Duration networkTimeout;

  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.audioCdnBaseUrl,
    required this.networkTimeout,
  });

  /// Reads `--dart-define` values and returns the resolved config.
  factory AppConfig.fromEnvironment() {
    const flavorRaw = String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.alquran.cloud/v1',
    );
    const audioCdn = String.fromEnvironment(
      'AUDIO_CDN_BASE_URL',
      defaultValue: 'https://cdn.islamic.network/quran/audio-surah',
    );
    const timeoutSeconds = int.fromEnvironment(
      'NETWORK_TIMEOUT_SECONDS',
      defaultValue: 15,
    );

    final flavor = switch (flavorRaw.toLowerCase()) {
      'prod' || 'production' || 'release' => AppFlavor.prod,
      'staging' || 'stage' => AppFlavor.staging,
      _ => AppFlavor.dev,
    };

    final config = AppConfig(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      audioCdnBaseUrl: audioCdn,
      networkTimeout: const Duration(seconds: timeoutSeconds),
    );
    config._assertHttpsOnly();
    return config;
  }

  bool get isProd => flavor == AppFlavor.prod;
  bool get isDebug => kDebugMode;

  /// Refuse to start with `http://` endpoints in release. Defence-in-depth on
  /// top of the Android network-security-config / iOS ATS rules.
  void _assertHttpsOnly() {
    assert(
      apiBaseUrl.startsWith('https://'),
      'API_BASE_URL must use HTTPS (got: $apiBaseUrl)',
    );
    assert(
      audioCdnBaseUrl.startsWith('https://'),
      'AUDIO_CDN_BASE_URL must use HTTPS (got: $audioCdnBaseUrl)',
    );
    if (kReleaseMode &&
        (!apiBaseUrl.startsWith('https://') ||
            !audioCdnBaseUrl.startsWith('https://'))) {
      throw StateError('Release builds require HTTPS endpoints.');
    }
  }
}
