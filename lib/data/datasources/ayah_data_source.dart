import '../models/ayah.dart';
import '../models/translation.dart';

abstract class IAyahDataSource {
  /// Returns cached ayahs for [surahNumber] with [editionId], empty list if
  /// none are cached yet.
  Future<List<Ayah>> getCachedAyahs({
    required int surahNumber,
    required String editionId,
  });

  /// Persists [ayahs] for a given (surah, edition) pair, replacing any
  /// previously cached rows.
  Future<void> cacheAyahs(List<Ayah> ayahs);

  /// Returns cached translations for [surahNumber] and [editionId].
  Future<List<Translation>> getCachedTranslations({
    required int surahNumber,
    required String editionId,
  });

  /// Persists [translations] for a given (surah, edition) pair.
  Future<void> cacheTranslations(List<Translation> translations);
}
