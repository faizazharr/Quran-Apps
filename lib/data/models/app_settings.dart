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

  /// Font size for Arabic ayah text. Default 26.0, range 18–40.
  final double arabicFontSize;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.localeTag,
    this.arabicEditionId = 'quran-simple',
    this.translationEditionId = 'id.indonesian',
    this.showTranslation = false,
    this.arabicFontSize = 26.0,
  });

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? localeTag,
    bool clearLocale = false,
    String? arabicEditionId,
    String? translationEditionId,
    bool? showTranslation,
    double? arabicFontSize,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    localeTag: clearLocale ? null : (localeTag ?? this.localeTag),
    arabicEditionId: arabicEditionId ?? this.arabicEditionId,
    translationEditionId: translationEditionId ?? this.translationEditionId,
    showTranslation: showTranslation ?? this.showTranslation,
    arabicFontSize: arabicFontSize ?? this.arabicFontSize,
  );

  @override
  List<Object?> get props => [
    themeMode,
    localeTag,
    arabicEditionId,
    translationEditionId,
    showTranslation,
    arabicFontSize,
  ];
}
