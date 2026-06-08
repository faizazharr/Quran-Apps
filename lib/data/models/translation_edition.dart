/// A curated translation edition available from the AlQuran Cloud API.
class TranslationEdition {
  final String id; // AlQuran Cloud edition identifier
  final String language; // Human-readable language name (in English)
  final String languageCode; // BCP-47 language code (e.g. 'en', 'id')
  final String translator; // Translator name / organization

  const TranslationEdition({
    required this.id,
    required this.language,
    required this.languageCode,
    required this.translator,
  });

  /// Display label shown in the picker.
  String get label => '$language — $translator';
}

/// Curated list of well-known translation editions.
/// Identifiers are validated against the AlQuran Cloud `/edition` endpoint.
class TranslationEditions {
  TranslationEditions._();

  static const List<TranslationEdition> all = [
    TranslationEdition(
      id: 'en.sahih',
      language: 'English',
      languageCode: 'en',
      translator: 'Saheeh International',
    ),
    TranslationEdition(
      id: 'en.pickthall',
      language: 'English',
      languageCode: 'en',
      translator: 'Pickthall',
    ),
    TranslationEdition(
      id: 'en.yusufali',
      language: 'English',
      languageCode: 'en',
      translator: 'Yusuf Ali',
    ),
    TranslationEdition(
      id: 'id.indonesian',
      language: 'Indonesian',
      languageCode: 'id',
      translator: 'Bahasa Indonesia',
    ),
    TranslationEdition(
      id: 'ms.basmeih',
      language: 'Malay',
      languageCode: 'ms',
      translator: 'Abdullah Muhammad Basmeih',
    ),
    TranslationEdition(
      id: 'ar.muyassar',
      language: 'Arabic',
      languageCode: 'ar',
      translator: 'Al-Muyassar',
    ),
    TranslationEdition(
      id: 'fr.hamidullah',
      language: 'French',
      languageCode: 'fr',
      translator: 'Hamidullah',
    ),
    TranslationEdition(
      id: 'de.aburida',
      language: 'German',
      languageCode: 'de',
      translator: 'Abu Rida',
    ),
    TranslationEdition(
      id: 'tr.diyanet',
      language: 'Turkish',
      languageCode: 'tr',
      translator: 'Diyanet İşleri',
    ),
    TranslationEdition(
      id: 'ru.kuliev',
      language: 'Russian',
      languageCode: 'ru',
      translator: 'Kuliev',
    ),
    TranslationEdition(
      id: 'zh.jian',
      language: 'Chinese',
      languageCode: 'zh',
      translator: 'Ma Jian',
    ),
    TranslationEdition(
      id: 'es.asad',
      language: 'Spanish',
      languageCode: 'es',
      translator: 'Muhammad Asad',
    ),
    TranslationEdition(
      id: 'nl.keyzer',
      language: 'Dutch',
      languageCode: 'nl',
      translator: 'Keyzer',
    ),
    TranslationEdition(
      id: 'ur.maududi',
      language: 'Urdu',
      languageCode: 'ur',
      translator: 'Maududi',
    ),
    TranslationEdition(
      id: 'bn.bengali',
      language: 'Bengali',
      languageCode: 'bn',
      translator: 'Muhiuddin Khan',
    ),
    TranslationEdition(
      id: 'fa.makarem',
      language: 'Persian',
      languageCode: 'fa',
      translator: 'Makarem Shirazi',
    ),
    TranslationEdition(
      id: 'bs.korkut',
      language: 'Bosnian',
      languageCode: 'bs',
      translator: 'Korkut',
    ),
    TranslationEdition(
      id: 'sq.nahi',
      language: 'Albanian',
      languageCode: 'sq',
      translator: 'Nahi',
    ),
    TranslationEdition(
      id: 'so.abduh',
      language: 'Somali',
      languageCode: 'so',
      translator: 'Abduh',
    ),
    TranslationEdition(
      id: 'ha.gumi',
      language: 'Hausa',
      languageCode: 'ha',
      translator: 'Gumi',
    ),
    TranslationEdition(
      id: 'sw.barwani',
      language: 'Swahili',
      languageCode: 'sw',
      translator: 'Al-Barwani',
    ),
    TranslationEdition(
      id: 'th.thai',
      language: 'Thai',
      languageCode: 'th',
      translator: 'King Fahad Quran Complex',
    ),
  ];

  /// Returns the best matching edition for [languageCode].
  /// Falls back to English (Saheeh International) if no match.
  static TranslationEdition forLocale(String languageCode) {
    final lower = languageCode.toLowerCase();
    return all.firstWhere(
      (e) => e.languageCode == lower,
      orElse: () => all.first, // en.sahih
    );
  }

  /// Finds an edition by its [id], or returns English as fallback.
  static TranslationEdition? findById(String id) {
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
