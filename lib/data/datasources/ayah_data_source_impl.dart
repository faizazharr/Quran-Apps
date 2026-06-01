import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../models/ayah.dart';
import '../models/translation.dart';
import '../services/database_service.dart';
import 'ayah_data_source.dart';

class AyahDataSourceImpl implements IAyahDataSource {
  final DatabaseService _db;

  AyahDataSourceImpl(this._db);

  @override
  Future<List<Ayah>> getCachedAyahs({
    required int surahNumber,
    required String editionId,
  }) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        DatabaseService.tableAyahs,
        where: 'surah_number = ? AND edition_id = ?',
        whereArgs: [surahNumber, editionId],
        orderBy: 'number_in_surah ASC',
      );
      return rows.map(Ayah.fromMap).toList();
    } catch (e) {
      throw LocalException('Failed to load cached ayahs: $e');
    }
  }

  @override
  Future<void> cacheAyahs(List<Ayah> ayahs) async {
    if (ayahs.isEmpty) return;
    try {
      final db = await _db.database;
      final batch = db.batch();
      // Replace entire surah/edition block atomically.
      batch.delete(
        DatabaseService.tableAyahs,
        where: 'surah_number = ? AND edition_id = ?',
        whereArgs: [ayahs.first.surahNumber, ayahs.first.editionId],
      );
      for (final ayah in ayahs) {
        batch.insert(
          DatabaseService.tableAyahs,
          ayah.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw LocalException('Failed to cache ayahs: $e');
    }
  }

  @override
  Future<List<Translation>> getCachedTranslations({
    required int surahNumber,
    required String editionId,
  }) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        DatabaseService.tableTranslations,
        where: 'surah_number = ? AND edition_id = ?',
        whereArgs: [surahNumber, editionId],
        orderBy: 'number_in_surah ASC',
      );
      return rows.map(Translation.fromMap).toList();
    } catch (e) {
      throw LocalException('Failed to load cached translations: $e');
    }
  }

  @override
  Future<void> cacheTranslations(List<Translation> translations) async {
    if (translations.isEmpty) return;
    try {
      final db = await _db.database;
      final batch = db.batch();
      batch.delete(
        DatabaseService.tableTranslations,
        where: 'surah_number = ? AND edition_id = ?',
        whereArgs: [
          translations.first.surahNumber,
          translations.first.editionId,
        ],
      );
      for (final t in translations) {
        batch.insert(
          DatabaseService.tableTranslations,
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw LocalException('Failed to cache translations: $e');
    }
  }
}
