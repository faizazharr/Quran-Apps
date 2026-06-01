import 'package:equatable/equatable.dart';

/// A saved playback position (manual bookmark or auto-saved last-played).
class Bookmark extends Equatable {
  final int? id;
  final int surahNumber;
  final String editionId;

  /// Playback position in milliseconds.
  final int positionMs;

  /// True when this row was written by the auto-save-last-played logic,
  /// false for user-created bookmarks.
  final bool isLastPlayed;

  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.surahNumber,
    required this.editionId,
    required this.positionMs,
    required this.isLastPlayed,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'surah_number': surahNumber,
    'edition_id': editionId,
    'position_ms': positionMs,
    'is_last_played': isLastPlayed ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory Bookmark.fromMap(Map<String, dynamic> map) => Bookmark(
    id: map['id'] as int?,
    surahNumber: map['surah_number'] as int,
    editionId: map['edition_id'] as String,
    positionMs: map['position_ms'] as int,
    isLastPlayed: (map['is_last_played'] as int) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );

  Bookmark copyWith({
    int? id,
    int? surahNumber,
    String? editionId,
    int? positionMs,
    bool? isLastPlayed,
    DateTime? createdAt,
  }) => Bookmark(
    id: id ?? this.id,
    surahNumber: surahNumber ?? this.surahNumber,
    editionId: editionId ?? this.editionId,
    positionMs: positionMs ?? this.positionMs,
    isLastPlayed: isLastPlayed ?? this.isLastPlayed,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    surahNumber,
    editionId,
    positionMs,
    isLastPlayed,
  ];
}
