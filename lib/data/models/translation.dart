import 'package:equatable/equatable.dart';

/// A translated text for a single ayah, keyed by surah + edition + verse.
class Translation extends Equatable {
  final int surahNumber;

  /// AlQuran Cloud edition identifier for this translation, e.g.
  /// `id.indonesian` or `en.sahih`.
  final String editionId;
  final int numberInSurah;
  final String text;

  const Translation({
    required this.surahNumber,
    required this.editionId,
    required this.numberInSurah,
    required this.text,
  });

  factory Translation.fromJson(
    Map<String, dynamic> json, {
    required int surahNumber,
    required String editionId,
  }) => Translation(
    surahNumber: surahNumber,
    editionId: editionId,
    numberInSurah: json['numberInSurah'] as int,
    text: json['text'] as String,
  );

  Map<String, dynamic> toMap() => {
    'surah_number': surahNumber,
    'edition_id': editionId,
    'number_in_surah': numberInSurah,
    'text': text,
  };

  factory Translation.fromMap(Map<String, dynamic> map) => Translation(
    surahNumber: map['surah_number'] as int,
    editionId: map['edition_id'] as String,
    numberInSurah: map['number_in_surah'] as int,
    text: map['text'] as String,
  );

  @override
  List<Object?> get props => [surahNumber, editionId, numberInSurah];
}
