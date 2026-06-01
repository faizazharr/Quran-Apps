import 'package:equatable/equatable.dart';

/// Theme preference stored by the user.
enum AppThemeMode { system, light, dark }

/// App-wide user preferences persisted in the settings table.
class AppSettings extends Equatable {
  final AppThemeMode themeMode;

  /// BCP-47 locale tag, e.g. `en` or `id`. Null = follow device locale.
  final String? localeTag;

  /// AlQuran Cloud edition identifier for the displayed Arabic text, e.g.
  /// `quran-simple` or `quran-uthmani`.
  final String arabicEditionId;

  /// AlQuran Cloud edition identifier for translations, e.g.
  /// `id.indonesian` or `en.sahih`.
  final String translationEditionId;

  final bool showTranslation;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.localeTag,
    this.arabicEditionId = 'quran-simple',
    this.translationEditionId = 'id.indonesian',
    this.showTranslation = false,
  });

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? localeTag,
    bool clearLocale = false,
    String? arabicEditionId,
    String? translationEditionId,
    bool? showTranslation,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    localeTag: clearLocale ? null : (localeTag ?? this.localeTag),
    arabicEditionId: arabicEditionId ?? this.arabicEditionId,
    translationEditionId: translationEditionId ?? this.translationEditionId,
    showTranslation: showTranslation ?? this.showTranslation,
  );

  @override
  List<Object?> get props => [
    themeMode,
    localeTag,
    arabicEditionId,
    translationEditionId,
    showTranslation,
  ];
}
