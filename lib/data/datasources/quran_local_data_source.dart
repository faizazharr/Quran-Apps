import '../models/edition.dart';
import '../models/surah.dart';

/// Contract for the on-device cache of Quran metadata.
///
/// Implementations persist Surahs and Editions so the app can run offline
/// after the first successful sync.
abstract class IQuranLocalDataSource {
  Future<List<Surah>> getSurahs();
  Future<List<Edition>> getEditions();

  Future<void> cacheSurahs(List<Surah> surahs);
  Future<void> cacheEditions(List<Edition> editions);

  /// True if both tables already contain data.
  Future<bool> hasCachedData();
}
