import 'package:equatable/equatable.dart';

/// Status of a per-surah audio download.
enum DownloadStatus { idle, queued, downloading, completed, failed }

/// Persistent record of a download request for one (surah, edition) pair.
class DownloadRecord extends Equatable {
  final int surahNumber;
  final String editionId;
  final DownloadStatus status;

  /// 0.0–1.0
  final double progress;

  /// Absolute path on-device once [status] is [DownloadStatus.completed].
  final String? filePath;

  final int bytesDownloaded;
  final int? totalBytes;
  final DateTime updatedAt;

  const DownloadRecord({
    required this.surahNumber,
    required this.editionId,
    required this.status,
    required this.progress,
    required this.updatedAt,
    this.filePath,
    this.bytesDownloaded = 0,
    this.totalBytes,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;

  Map<String, dynamic> toMap() => {
    'surah_number': surahNumber,
    'edition_id': editionId,
    'status': status.name,
    'progress': progress,
    'file_path': filePath,
    'bytes_downloaded': bytesDownloaded,
    'total_bytes': totalBytes,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory DownloadRecord.fromMap(Map<String, dynamic> map) => DownloadRecord(
    surahNumber: map['surah_number'] as int,
    editionId: map['edition_id'] as String,
    status: DownloadStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => DownloadStatus.idle,
    ),
    progress: (map['progress'] as num).toDouble(),
    filePath: map['file_path'] as String?,
    bytesDownloaded: map['bytes_downloaded'] as int,
    totalBytes: map['total_bytes'] as int?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
  );

  DownloadRecord copyWith({
    DownloadStatus? status,
    double? progress,
    String? filePath,
    int? bytesDownloaded,
    int? totalBytes,
    DateTime? updatedAt,
  }) => DownloadRecord(
    surahNumber: surahNumber,
    editionId: editionId,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    filePath: filePath ?? this.filePath,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes ?? this.totalBytes,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    surahNumber,
    editionId,
    status,
    progress,
    filePath,
  ];
}
