// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Quran Player';

  @override
  String get searchHint => 'Search surah or reciter…';

  @override
  String get continueListening => 'Continue listening';

  @override
  String get settings => 'Settings';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerOff => 'Off';

  @override
  String get sleepTimerEndOfSurah => 'End of surah';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Downloading';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get translation => 'Translation';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get hideTranslation => 'Hide translation';

  @override
  String ayahNumber(int number) {
    return 'Ayah $number';
  }

  @override
  String get cloudSync => 'Cloud sync';

  @override
  String get cloudSyncNotConfigured => 'Cloud sync is not configured.';
}
