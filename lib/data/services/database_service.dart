import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for opening the application database.
///
/// Owns the schema and is the only place where SQL CREATE statements live.
class DatabaseService {
  static const String _dbName = 'quran_player.db';
  static const int _dbVersion = 2;

  /// Tables — exposed as constants so data sources don't hard-code strings.
  static const String tableSurahs = 'surahs';
  static const String tableEditions = 'editions';
  static const String tableBookmarks = 'bookmarks';
  static const String tableDownloads = 'downloads';
  static const String tableAyahs = 'ayahs';
  static const String tableTranslations = 'translations';
  static const String tableSettings = 'settings';

  Database? _db;

  /// Returns a singleton [Database] instance, opening it on first use.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSurahs(db);
    await _createEditions(db);
    await _createV2Tables(db);
  }

  /// Incremental migrations. Each `if` block handles ONE version bump and
  /// must be idempotent enough to survive a partially-applied upgrade.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
  }

  Future<void> _createSurahs(Database db) => db.execute('''
      CREATE TABLE $tableSurahs (
        number INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        englishName TEXT NOT NULL,
        englishNameTranslation TEXT NOT NULL,
        numberOfAyahs INTEGER NOT NULL,
        revelationType TEXT NOT NULL
      )
    ''');

  Future<void> _createEditions(Database db) => db.execute('''
      CREATE TABLE $tableEditions (
        identifier TEXT PRIMARY KEY,
        language TEXT NOT NULL,
        name TEXT NOT NULL,
        englishName TEXT NOT NULL,
        format TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

  Future<void> _createV2Tables(Database db) async {
    // Last-played position + manual bookmarks. One row per (surah, edition).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        edition_id TEXT NOT NULL,
        position_ms INTEGER NOT NULL DEFAULT 0,
        is_last_played INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        UNIQUE(surah_number, edition_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_last '
      'ON $tableBookmarks(is_last_played)',
    );

    // Download state per (surah, edition). file_path is null until completed.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDownloads (
        surah_number INTEGER NOT NULL,
        edition_id TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        file_path TEXT,
        bytes_downloaded INTEGER NOT NULL DEFAULT 0,
        total_bytes INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(surah_number, edition_id)
      )
    ''');

    // Cached ayah text per (surah, edition).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAyahs (
        surah_number INTEGER NOT NULL,
        edition_id TEXT NOT NULL,
        number_in_surah INTEGER NOT NULL,
        global_number INTEGER NOT NULL,
        text TEXT NOT NULL,
        juz INTEGER,
        page INTEGER,
        PRIMARY KEY(surah_number, edition_id, number_in_surah)
      )
    ''');

    // Cached translations indexed by ayah.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTranslations (
        surah_number INTEGER NOT NULL,
        edition_id TEXT NOT NULL,
        number_in_surah INTEGER NOT NULL,
        text TEXT NOT NULL,
        PRIMARY KEY(surah_number, edition_id, number_in_surah)
      )
    ''');

    // Simple key/value store for app settings (theme, locale, etc.).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
