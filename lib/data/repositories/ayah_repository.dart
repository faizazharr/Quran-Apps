import '../../core/result/result.dart';
import '../models/ayah.dart';
import '../models/translation.dart';

abstract class IAyahRepository {
  /// Returns ayahs for the given surah and Arabic text edition.
  /// Uses cache-first strategy; fetches from network if not cached.
  Future<Result<List<Ayah>>> getAyahs({
    required int surahNumber,
    required String editionId,
    bool forceRefresh = false,
  });

  /// Returns translations for the given surah and translation edition.
  Future<Result<List<Translation>>> getTranslations({
    required int surahNumber,
    required String editionId,
    bool forceRefresh = false,
  });
}
