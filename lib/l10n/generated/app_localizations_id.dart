// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Quran Player';

  @override
  String get searchHint => 'Cari surah atau qari…';

  @override
  String get continueListening => 'Lanjutkan mendengarkan';

  @override
  String get settings => 'Pengaturan';

  @override
  String get darkMode => 'Mode gelap';

  @override
  String get themeSystem => 'Ikuti sistem';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String get language => 'Bahasa';

  @override
  String get sleepTimer => 'Timer tidur';

  @override
  String get sleepTimerOff => 'Mati';

  @override
  String get sleepTimerEndOfSurah => 'Akhir surah';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes menit';
  }

  @override
  String get download => 'Unduh';

  @override
  String get downloading => 'Mengunduh';

  @override
  String get downloaded => 'Tersimpan';

  @override
  String get cancel => 'Batal';

  @override
  String get delete => 'Hapus';

  @override
  String get translation => 'Terjemahan';

  @override
  String get showTranslation => 'Tampilkan terjemahan';

  @override
  String get hideTranslation => 'Sembunyikan terjemahan';

  @override
  String ayahNumber(int number) {
    return 'Ayat $number';
  }

  @override
  String get cloudSync => 'Sinkronisasi cloud';

  @override
  String get cloudSyncNotConfigured =>
      'Sinkronisasi cloud belum dikonfigurasi.';
}
