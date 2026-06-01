import 'package:equatable/equatable.dart';

/// A single verse (ayah) from the Quran, as returned by AlQuran Cloud API.
class Ayah extends Equatable {
  final int surahNumber;
  final String editionId;
  final int numberInSurah;
  final int globalNumber;
  final String text;
  final int? juz;
  final int? page;

  const Ayah({
    required this.surahNumber,
    required this.editionId,
    required this.numberInSurah,
    required this.globalNumber,
    required this.text,
    this.juz,
    this.page,
  });

  factory Ayah.fromJson(
    Map<String, dynamic> json, {
    required int surahNumber,
    required String editionId,
  }) => Ayah(
    surahNumber: surahNumber,
    editionId: editionId,
    numberInSurah: json['numberInSurah'] as int,
    globalNumber: json['number'] as int,
    text: json['text'] as String,
    juz: json['juz'] as int?,
    page: json['page'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'surah_number': surahNumber,
    'edition_id': editionId,
    'number_in_surah': numberInSurah,
    'global_number': globalNumber,
    'text': text,
    'juz': juz,
    'page': page,
  };

  factory Ayah.fromMap(Map<String, dynamic> map) => Ayah(
    surahNumber: map['surah_number'] as int,
    editionId: map['edition_id'] as String,
    numberInSurah: map['number_in_surah'] as int,
    globalNumber: map['global_number'] as int,
    text: map['text'] as String,
    juz: map['juz'] as int?,
    page: map['page'] as int?,
  );

  @override
  List<Object?> get props => [surahNumber, editionId, numberInSurah];
}
