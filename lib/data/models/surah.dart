import 'package:equatable/equatable.dart';

/// Metadata describing a single Surah from the AlQuran Cloud API.
class Surah extends Equatable {
  final int number;
  final String name; // Arabic name
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'] as int,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: json['numberOfAyahs'] as int? ?? 0,
      revelationType: json['revelationType'] as String? ?? '',
    );
  }

  /// Row representation for sqflite.
  Map<String, Object?> toMap() => {
    'number': number,
    'name': name,
    'englishName': englishName,
    'englishNameTranslation': englishNameTranslation,
    'numberOfAyahs': numberOfAyahs,
    'revelationType': revelationType,
  };

  /// Builds a [Surah] from a sqflite row.
  factory Surah.fromMap(Map<String, Object?> row) {
    return Surah(
      number: row['number'] as int,
      name: row['name'] as String? ?? '',
      englishName: row['englishName'] as String? ?? '',
      englishNameTranslation: row['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: row['numberOfAyahs'] as int? ?? 0,
      revelationType: row['revelationType'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
    number,
    name,
    englishName,
    englishNameTranslation,
    numberOfAyahs,
    revelationType,
  ];
}
