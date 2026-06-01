import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../models/bookmark.dart';
import '../services/database_service.dart';
import 'bookmark_data_source.dart';

class BookmarkDataSourceImpl implements IBookmarkDataSource {
  final DatabaseService _db;

  BookmarkDataSourceImpl(this._db);

  @override
  Future<void> upsert(Bookmark bookmark) async {
    try {
      final db = await _db.database;
      await db.insert(
        DatabaseService.tableBookmarks,
        bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalException('Bookmark upsert failed: $e');
    }
  }

  @override
  Future<List<Bookmark>> getBookmarks() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        DatabaseService.tableBookmarks,
        where: 'is_last_played = 0',
        orderBy: 'created_at DESC',
      );
      return rows.map(Bookmark.fromMap).toList();
    } catch (e) {
      throw LocalException('Failed to load bookmarks: $e');
    }
  }

  @override
  Future<Bookmark?> getLastPlayed() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        DatabaseService.tableBookmarks,
        where: 'is_last_played = 1',
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Bookmark.fromMap(rows.first);
    } catch (e) {
      throw LocalException('Failed to load last played: $e');
    }
  }

  @override
  Future<void> saveLastPlayed({
    required int surahNumber,
    required String editionId,
    required int positionMs,
  }) async {
    try {
      final db = await _db.database;
      // Clear previous last-played rows, then insert the new one.
      await db.delete(
        DatabaseService.tableBookmarks,
        where: 'is_last_played = 1',
      );
      final bookmark = Bookmark(
        surahNumber: surahNumber,
        editionId: editionId,
        positionMs: positionMs,
        isLastPlayed: true,
        createdAt: DateTime.now(),
      );
      await db.insert(
        DatabaseService.tableBookmarks,
        bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalException('Failed to save last played: $e');
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      final db = await _db.database;
      await db.delete(
        DatabaseService.tableBookmarks,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw LocalException('Failed to delete bookmark: $e');
    }
  }
}
