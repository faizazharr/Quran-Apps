import '../../core/result/result.dart';
import '../models/bookmark.dart';

abstract class IBookmarkRepository {
  Future<Result<List<Bookmark>>> getBookmarks();
  Future<Result<Bookmark?>> getLastPlayed();
  Future<Result<void>> saveLastPlayed({
    required int surahNumber,
    required String editionId,
    required int positionMs,
  });
  Future<Result<void>> addBookmark({
    required int surahNumber,
    required String editionId,
    int positionMs = 0,
  });
  Future<Result<void>> deleteBookmark(int id);
}
