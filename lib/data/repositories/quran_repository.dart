import '../../core/result/result.dart';
import '../models/edition.dart';
import '../models/surah.dart';
import '../models/track.dart';

/// Contract every track repository must satisfy.
///
/// Returns a [Result] so callers handle success/failure exhaustively without
/// try/catch noise (DIP + cleaner error flow).
abstract class IQuranRepository {
  /// Returns the cross-product of every surah × featured reciter. Kept for
  /// backward compatibility with the original UI / tests.
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false});

  /// Returns the 114 surahs (deduplicated, cache-first).
  Future<Result<List<Surah>>> getSurahs({bool forceRefresh = false});

  /// Returns the curated reciters known to have full-surah audio.
  Future<Result<List<Edition>>> getReciters();

  /// Filters [Track]s by [query] (fuzzy, diacritic-insensitive).
  Future<Result<List<Track>>> search(String query);

  /// Filters the surah list by [query] (fuzzy, diacritic-insensitive).
  Future<Result<List<Surah>>> searchSurahs(String query);
}
