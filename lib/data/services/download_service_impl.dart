import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../models/download_record.dart';
import '../services/database_service.dart';
import 'download_service.dart';

/// Download manager that streams audio files to disk, persisting state in
/// sqflite. One download runs at a time; others are queued.
class DownloadServiceImpl implements IDownloadService {
  final DatabaseService _db;
  final http.Client _http;

  final _controller = StreamController<List<DownloadRecord>>.broadcast();
  final _active = <String, _ActiveDownload>{};

  DownloadServiceImpl(this._db, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  String _key(int surahNumber, String editionId) => '$surahNumber-$editionId';

  @override
  Stream<List<DownloadRecord>> get downloadsStream => _controller.stream;

  @override
  Future<List<DownloadRecord>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(DatabaseService.tableDownloads);
    return rows.map(DownloadRecord.fromMap).toList();
  }

  @override
  Future<DownloadRecord?> get({
    required int surahNumber,
    required String editionId,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseService.tableDownloads,
      where: 'surah_number = ? AND edition_id = ?',
      whereArgs: [surahNumber, editionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DownloadRecord.fromMap(rows.first);
  }

  @override
  Future<void> enqueue({
    required int surahNumber,
    required String editionId,
    required String audioUrl,
  }) async {
    final key = _key(surahNumber, editionId);
    if (_active.containsKey(key)) return; // already running

    final record = DownloadRecord(
      surahNumber: surahNumber,
      editionId: editionId,
      status: DownloadStatus.queued,
      progress: 0,
      updatedAt: DateTime.now(),
    );
    await _persist(record);
    _notifyListeners();
    _startDownload(
      surahNumber: surahNumber,
      editionId: editionId,
      audioUrl: audioUrl,
    );
  }

  void _startDownload({
    required int surahNumber,
    required String editionId,
    required String audioUrl,
  }) {
    final key = _key(surahNumber, editionId);
    final cancelToken = _CancelToken();
    _active[key] = _ActiveDownload(cancelToken: cancelToken);

    Future(() async {
      try {
        // Validate the URL is HTTPS before downloading.
        final uri = Uri.parse(audioUrl);
        if (uri.scheme != 'https') {
          throw const RemoteException('Download URL must use HTTPS.');
        }

        await _updateStatus(surahNumber, editionId, DownloadStatus.downloading);
        _notifyListeners();

        final dir = await _ensureDir();
        final file = File(p.join(dir.path, '$key.mp3'));

        final request = http.Request('GET', uri);
        final response = await _http.send(request);
        final total = response.contentLength ?? 0;

        var received = 0;
        final sink = file.openWrite();
        await for (final chunk in response.stream) {
          if (cancelToken.isCancelled) {
            await sink.close();
            await file.delete();
            return;
          }
          sink.add(chunk);
          received += chunk.length;
          final progress = total > 0 ? received / total : 0.0;
          await _updateProgress(
            surahNumber,
            editionId,
            progress,
            received,
            total,
          );
          _notifyListeners();
        }
        await sink.close();

        if (cancelToken.isCancelled) {
          await file.delete();
          return;
        }

        await _updateCompleted(surahNumber, editionId, file.path);
        _notifyListeners();
      } catch (e) {
        await _updateStatus(surahNumber, editionId, DownloadStatus.failed);
        _notifyListeners();
      } finally {
        _active.remove(key);
      }
    });
  }

  @override
  Future<void> cancel({
    required int surahNumber,
    required String editionId,
  }) async {
    final key = _key(surahNumber, editionId);
    _active[key]?.cancelToken.cancel();
    _active.remove(key);
    final db = await _db.database;
    await db.delete(
      DatabaseService.tableDownloads,
      where: 'surah_number = ? AND edition_id = ?',
      whereArgs: [surahNumber, editionId],
    );
    _notifyListeners();
  }

  @override
  Future<void> delete({
    required int surahNumber,
    required String editionId,
  }) async {
    final key = _key(surahNumber, editionId);
    _active[key]?.cancelToken.cancel();
    _active.remove(key);

    final record = await get(surahNumber: surahNumber, editionId: editionId);
    if (record?.filePath != null) {
      final file = File(record!.filePath!);
      if (await file.exists()) await file.delete();
    }

    final db = await _db.database;
    await db.delete(
      DatabaseService.tableDownloads,
      where: 'surah_number = ? AND edition_id = ?',
      whereArgs: [surahNumber, editionId],
    );
    _notifyListeners();
  }

  Future<Directory> _ensureDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'audio_downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _persist(DownloadRecord record) async {
    final db = await _db.database;
    await db.insert(
      DatabaseService.tableDownloads,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _updateStatus(
    int surahNumber,
    String editionId,
    DownloadStatus status,
  ) async {
    final db = await _db.database;
    await db.update(
      DatabaseService.tableDownloads,
      {
        'status': status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'surah_number = ? AND edition_id = ?',
      whereArgs: [surahNumber, editionId],
    );
  }

  Future<void> _updateProgress(
    int surahNumber,
    String editionId,
    double progress,
    int bytes,
    int total,
  ) async {
    final db = await _db.database;
    await db.update(
      DatabaseService.tableDownloads,
      {
        'progress': progress,
        'bytes_downloaded': bytes,
        'total_bytes': total,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'surah_number = ? AND edition_id = ?',
      whereArgs: [surahNumber, editionId],
    );
  }

  Future<void> _updateCompleted(
    int surahNumber,
    String editionId,
    String filePath,
  ) async {
    final db = await _db.database;
    await db.update(
      DatabaseService.tableDownloads,
      {
        'status': DownloadStatus.completed.name,
        'progress': 1.0,
        'file_path': filePath,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'surah_number = ? AND edition_id = ?',
      whereArgs: [surahNumber, editionId],
    );
  }

  Future<void> _notifyListeners() async {
    if (_controller.isClosed) return;
    final all = await getAll();
    _controller.add(all);
  }

  void dispose() => _controller.close();
}

class _CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class _ActiveDownload {
  final _CancelToken cancelToken;
  _ActiveDownload({required this.cancelToken});
}
