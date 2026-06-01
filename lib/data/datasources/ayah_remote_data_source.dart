import '../models/ayah.dart';
import '../models/translation.dart';

abstract class IAyahRemoteDataSource {
  /// Fetches all ayahs for [surahNumber] in [editionId] from AlQuran Cloud.
  Future<List<Ayah>> fetchAyahs({
    required int surahNumber,
    required String editionId,
  });

  /// Fetches translations for [surahNumber] in [editionId].
  Future<List<Translation>> fetchTranslations({
    required int surahNumber,
    required String editionId,
  });
}
