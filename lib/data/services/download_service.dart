import '../models/download_record.dart';

/// Abstract interface for the audio download manager.
abstract class IDownloadService {
  /// All current download records as a broadcast stream.
  Stream<List<DownloadRecord>> get downloadsStream;

  /// Enqueues a download for the given (surah, edition) pair and [audioUrl].
  Future<void> enqueue({
    required int surahNumber,
    required String editionId,
    required String audioUrl,
  });

  /// Cancels and removes a pending or active download.
  Future<void> cancel({required int surahNumber, required String editionId});

  /// Deletes the local file and the download record.
  Future<void> delete({required int surahNumber, required String editionId});

  /// Returns all persisted download records.
  Future<List<DownloadRecord>> getAll();

  /// Returns the record for the given key, or null if it doesn't exist.
  Future<DownloadRecord?> get({
    required int surahNumber,
    required String editionId,
  });
}
