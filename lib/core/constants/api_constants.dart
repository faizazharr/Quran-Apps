import '../config/app_config.dart';

/// API endpoint helpers for AlQuran Cloud.
///
/// All values are sourced from [AppConfig] so they can be swapped at build
/// time via `--dart-define` (see `lib/core/config/app_config.dart`).
class ApiConstants {
  ApiConstants._();

  static final AppConfig _cfg = AppConfig.fromEnvironment();

  /// Base URL for the AlQuran Cloud REST API.
  static String get baseUrl => _cfg.apiBaseUrl;

  /// CDN base for full-surah audio files.
  /// Format: {audioCdn}/{bitrate}/{editionIdentifier}/{surahNumber}.mp3
  static String get audioCdn => _cfg.audioCdnBaseUrl;

  /// Default bitrate used for streaming surah audio.
  static const String defaultBitrate = '128';

  /// Builds a full-surah audio URL for the given reciter edition.
  static String surahAudioUrl({
    required String editionIdentifier,
    required int surahNumber,
    String bitrate = defaultBitrate,
  }) {
    return '$audioCdn/$bitrate/$editionIdentifier/$surahNumber.mp3';
  }
}
