import '../../core/result/result.dart';
import '../datasources/bookmark_data_source.dart';
import '../models/bookmark.dart';
import 'bookmark_repository.dart';

class BookmarkRepositoryImpl implements IBookmarkRepository {
  final IBookmarkDataSource _local;

  BookmarkRepositoryImpl(this._local);

  @override
  Future<Result<List<Bookmark>>> getBookmarks() =>
      runCatching(_local.getBookmarks);

  @override
  Future<Result<Bookmark?>> getLastPlayed() =>
      runCatching(_local.getLastPlayed);

  @override
  Future<Result<void>> saveLastPlayed({
    required int surahNumber,
    required String editionId,
    required int positionMs,
  }) => runCatching(
    () => _local.saveLastPlayed(
      surahNumber: surahNumber,
      editionId: editionId,
      positionMs: positionMs,
    ),
  );

  @override
  Future<Result<void>> addBookmark({
    required int surahNumber,
    required String editionId,
    int positionMs = 0,
  }) => runCatching(
    () => _local.upsert(
      Bookmark(
        surahNumber: surahNumber,
        editionId: editionId,
        positionMs: positionMs,
        isLastPlayed: false,
        createdAt: DateTime.now(),
      ),
    ),
  );

  @override
  Future<Result<void>> deleteBookmark(int id) =>
      runCatching(() => _local.delete(id));
}
