/// Serialized representation of a randomly selected Ayah citation
/// displayed on the home-screen quote card and in daily reminders.
class QuoteModel {
  final int surahNumber;
  final String surahEnglishName;
  final String surahArabicName;
  final int ayahNumber;
  final String arabicText;
  final String? translation;
  final DateTime generatedAt;

  const QuoteModel({
    required this.surahNumber,
    required this.surahEnglishName,
    required this.surahArabicName,
    required this.ayahNumber,
    required this.arabicText,
    required this.translation,
    required this.generatedAt,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      surahNumber: json['surahNumber'] as int,
      surahEnglishName: json['surahEnglishName'] as String,
      surahArabicName: json['surahArabicName'] as String,
      ayahNumber: json['ayahNumber'] as int,
      arabicText: json['arabicText'] as String,
      translation: json['translation'] as String?,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'surahNumber': surahNumber,
    'surahEnglishName': surahEnglishName,
    'surahArabicName': surahArabicName,
    'ayahNumber': ayahNumber,
    'arabicText': arabicText,
    'translation': translation,
    'generatedAt': generatedAt.toIso8601String(),
  };
}
