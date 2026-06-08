import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/result/result.dart';
import '../../core/utils/random_service.dart';
import '../models/quote.dart';
import '../repositories/ayah_repository.dart';
import '../repositories/quran_repository.dart';
import '../repositories/settings_repository.dart';

abstract class IQuoteService {
  /// Fetches a new random quote from the repository.
  Future<Result<QuoteModel>> fetchNewRandomQuote();

  /// Gets the current cached quote for today, or generates a new one if stale.
  Future<Result<QuoteModel>> getDailyQuote({bool forceRefresh = false});
}

class QuoteServiceImpl implements IQuoteService {
  final IQuranRepository _quranRepo;
  final IAyahRepository _ayahRepo;
  final ISettingsRepository _settingsRepo;
  final IRandomService _random;
  final Future<SharedPreferences> _prefsFuture;

  static const String _kCachedQuoteKey = 'cached_quote_of_the_day';

  QuoteServiceImpl({
    required IQuranRepository quranRepo,
    required IAyahRepository ayahRepo,
    required ISettingsRepository settingsRepo,
    required IRandomService random,
    Future<SharedPreferences>? prefsFuture,
  }) : _quranRepo = quranRepo,
       _ayahRepo = ayahRepo,
       _settingsRepo = settingsRepo,
       _random = random,
       _prefsFuture = prefsFuture ?? SharedPreferences.getInstance();

  @override
  Future<Result<QuoteModel>> fetchNewRandomQuote() async {
    return runCatching(() async {
      // 1. Get all 114 surahs
      final surahsResult = await _quranRepo.getSurahs();
      final surahs = surahsResult.dataOrNull;
      if (surahs == null || surahs.isEmpty) {
        throw Exception('Could not fetch surahs to pick random quote');
      }

      // 2. Pick a random surah
      final surah = surahs[_random.nextInt(surahs.length)];

      // 3. Get ayahs for this surah
      final settingsResult = await _settingsRepo.load();
      final settings = settingsResult.dataOrNull;
      final arabicEdition = settings?.arabicEditionId ?? 'quran-simple';
      final translationEdition = settings?.translationEditionId ?? 'en.walk';

      final ayahsResult = await _ayahRepo.getAyahs(
        surahNumber: surah.number,
        editionId: arabicEdition,
      );
      final ayahs = ayahsResult.dataOrNull;
      if (ayahs == null || ayahs.isEmpty) {
        throw Exception('Could not fetch ayahs for surah ${surah.number}');
      }

      // 4. Pick a random ayah
      final ayah = ayahs[_random.nextInt(ayahs.length)];

      // 5. Get translation for this surah/ayah
      final translationsResult = await _ayahRepo.getTranslations(
        surahNumber: surah.number,
        editionId: translationEdition,
      );
      final translations = translationsResult.dataOrNull;
      String? translationText;
      if (translations != null && translations.isNotEmpty) {
        // Find matching translation by numberInSurah (1-based index is numberInSurah, list is 0-based)
        final matchIdx = ayah.numberInSurah - 1;
        if (matchIdx >= 0 && matchIdx < translations.length) {
          translationText = translations[matchIdx].text;
        }
      }

      final quote = QuoteModel(
        surahNumber: surah.number,
        surahEnglishName: surah.englishName,
        surahArabicName: surah.name,
        ayahNumber: ayah.numberInSurah,
        arabicText: ayah.text,
        translation: translationText,
        generatedAt: DateTime.now(),
      );

      // Save to SharedPreferences for offline reading & sharing with native widgets
      final prefs = await _prefsFuture;
      await prefs.setString(_kCachedQuoteKey, jsonEncode(quote.toJson()));

      return quote;
    });
  }

  @override
  Future<Result<QuoteModel>> getDailyQuote({bool forceRefresh = false}) async {
    return runCatching(() async {
      final prefs = await _prefsFuture;
      final raw = prefs.getString(_kCachedQuoteKey);

      if (raw != null && !forceRefresh) {
        final cached = QuoteModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        final diff = DateTime.now().difference(cached.generatedAt);
        // Reuse for 24 hours
        if (diff.inHours < 24) {
          return cached;
        }
      }

      // Stale or missing — fetch a new one
      final newQuoteResult = await fetchNewRandomQuote();
      if (newQuoteResult.isFailure) {
        throw newQuoteResult.errorOrNull!;
      }
      return newQuoteResult.dataOrNull!;
    });
  }
}
