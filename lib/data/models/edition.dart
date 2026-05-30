import 'package:equatable/equatable.dart';

/// Represents an audio "edition" (reciter) from AlQuran Cloud.
class Edition extends Equatable {
  final String identifier;
  final String language;
  final String name;
  final String englishName;
  final String format;
  final String type;

  const Edition({
    required this.identifier,
    required this.language,
    required this.name,
    required this.englishName,
    required this.format,
    required this.type,
  });

  factory Edition.fromJson(Map<String, dynamic> json) {
    return Edition(
      identifier: json['identifier'] as String? ?? '',
      language: json['language'] as String? ?? '',
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      format: json['format'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  /// Row representation for sqflite.
  Map<String, Object?> toMap() => {
    'identifier': identifier,
    'language': language,
    'name': name,
    'englishName': englishName,
    'format': format,
    'type': type,
  };

  /// Builds an [Edition] from a sqflite row.
  factory Edition.fromMap(Map<String, Object?> row) {
    return Edition(
      identifier: row['identifier'] as String? ?? '',
      language: row['language'] as String? ?? '',
      name: row['name'] as String? ?? '',
      englishName: row['englishName'] as String? ?? '',
      format: row['format'] as String? ?? '',
      type: row['type'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
    identifier,
    language,
    name,
    englishName,
    format,
    type,
  ];
}
