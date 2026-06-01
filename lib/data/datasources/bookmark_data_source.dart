import '../models/bookmark.dart';

abstract class IBookmarkDataSource {
  /// Upserts [bookmark] (insert or replace by surah_number + edition_id).
  Future<void> upsert(Bookmark bookmark);

  /// Returns all user-created bookmarks (is_last_played = 0), newest first.
  Future<List<Bookmark>> getBookmarks();

  /// Returns the single last-played row, or null if none exists.
  Future<Bookmark?> getLastPlayed();

  /// Saves (or overwrites) the last-played record for this (surah, edition).
  Future<void> saveLastPlayed({
    required int surahNumber,
    required String editionId,
    required int positionMs,
  });

  /// Deletes a bookmark by its [id].
  Future<void> delete(int id);
}
