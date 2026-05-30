import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../models/edition.dart';
import '../models/surah.dart';
import '../services/database_service.dart';
import 'quran_local_data_source.dart';

/// sqflite-backed implementation of the local cache.
///
/// All write operations replace existing rows, so the cache always mirrors
/// the latest successful remote sync.
class QuranLocalDataSourceImpl implements IQuranLocalDataSource {
  final DatabaseService _databaseService;

  QuranLocalDataSourceImpl(this._databaseService);

  @override
  Future<List<Surah>> getSurahs() async {
    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        DatabaseService.tableSurahs,
        orderBy: 'number ASC',
      );
      return rows.map(Surah.fromMap).toList(growable: false);
    } catch (e) {
      throw LocalException('Failed to read surahs: $e');
    }
  }

  @override
  Future<List<Edition>> getEditions() async {
    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        DatabaseService.tableEditions,
        orderBy: 'englishName ASC',
      );
      return rows.map(Edition.fromMap).toList(growable: false);
    } catch (e) {
      throw LocalException('Failed to read editions: $e');
    }
  }

  @override
  Future<void> cacheSurahs(List<Surah> surahs) async {
    try {
      final db = await _databaseService.database;
      final batch = db.batch();
      batch.delete(DatabaseService.tableSurahs);
      for (final s in surahs) {
        batch.insert(
          DatabaseService.tableSurahs,
          s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw LocalException('Failed to cache surahs: $e');
    }
  }

  @override
  Future<void> cacheEditions(List<Edition> editions) async {
    try {
      final db = await _databaseService.database;
      final batch = db.batch();
      batch.delete(DatabaseService.tableEditions);
      for (final e in editions) {
        batch.insert(
          DatabaseService.tableEditions,
          e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw LocalException('Failed to cache editions: $e');
    }
  }

  @override
  Future<bool> hasCachedData() async {
    try {
      final db = await _databaseService.database;
      final surahCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseService.tableSurahs}',
        ),
      );
      final editionCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseService.tableEditions}',
        ),
      );
      return (surahCount ?? 0) > 0 && (editionCount ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }
}
