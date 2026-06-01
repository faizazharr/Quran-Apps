import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../models/app_settings.dart';
import '../services/database_service.dart';
import 'settings_data_source.dart';

/// Key constants for the settings table.
class _K {
  static const themeMode = 'theme_mode';
  static const localeTag = 'locale_tag';
  static const arabicEditionId = 'arabic_edition_id';
  static const translationEditionId = 'translation_edition_id';
  static const showTranslation = 'show_translation';
}

class SettingsDataSourceImpl implements ISettingsDataSource {
  final DatabaseService _db;

  SettingsDataSourceImpl(this._db);

  @override
  Future<AppSettings> load() async {
    try {
      final db = await _db.database;
      final rows = await db.query(DatabaseService.tableSettings);
      final map = {
        for (final r in rows) r['key'] as String: r['value'] as String?,
      };

      return AppSettings(
        themeMode: AppThemeMode.values.firstWhere(
          (e) => e.name == map[_K.themeMode],
          orElse: () => AppThemeMode.system,
        ),
        localeTag: map[_K.localeTag],
        arabicEditionId:
            map[_K.arabicEditionId] ?? AppSettings.defaults.arabicEditionId,
        translationEditionId:
            map[_K.translationEditionId] ??
            AppSettings.defaults.translationEditionId,
        showTranslation: map[_K.showTranslation] == '1',
      );
    } catch (e) {
      throw LocalException('Failed to load settings: $e');
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      final db = await _db.database;
      final batch = db.batch();
      void put(String key, String? value) => batch.insert(
        DatabaseService.tableSettings,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      put(_K.themeMode, settings.themeMode.name);
      put(_K.localeTag, settings.localeTag);
      put(_K.arabicEditionId, settings.arabicEditionId);
      put(_K.translationEditionId, settings.translationEditionId);
      put(_K.showTranslation, settings.showTranslation ? '1' : '0');
      await batch.commit(noResult: true);
    } catch (e) {
      throw LocalException('Failed to save settings: $e');
    }
  }
}
