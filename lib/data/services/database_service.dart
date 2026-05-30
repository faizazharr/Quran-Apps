import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for opening the application database.
///
/// Owns the schema and is the only place where SQL CREATE statements live.
class DatabaseService {
  static const String _dbName = 'quran_player.db';
  static const int _dbVersion = 1;

  /// Tables — exposed as constants so data sources don't hard-code strings.
  static const String tableSurahs = 'surahs';
  static const String tableEditions = 'editions';

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
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSurahs (
        number INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        englishName TEXT NOT NULL,
        englishNameTranslation TEXT NOT NULL,
        numberOfAyahs INTEGER NOT NULL,
        revelationType TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableEditions (
        identifier TEXT PRIMARY KEY,
        language TEXT NOT NULL,
        name TEXT NOT NULL,
        englishName TEXT NOT NULL,
        format TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
