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

  /// Returns the best edition for a full device locale (language + country).
  ///
  /// Priority:
  ///   1. Direct language-code match (same as [forLocale]).
  ///   2. Country-code fallback — used when the device language has no match
  ///      in [all] but the country implies a common Muslim-majority language
  ///      (e.g. `sr_BA` → Bosnian, `ur_PK` → already matched by step 1).
  ///   3. Ultimate fallback: English (Saheeh International).
  ///
  /// [languageCode] is a BCP-47 language code (e.g. `'id'`, `'en'`).
  /// [countryCode] is an ISO 3166-1 alpha-2 country code (e.g. `'ID'`, `'MY'`).
  static TranslationEdition forFullLocale(
    String languageCode, [
    String? countryCode,
  ]) {
    final lang = languageCode.toLowerCase();
    final country = countryCode?.toUpperCase();

    // 1. Direct language match.
    final byLang = all.where((e) => e.languageCode == lang).toList();
    if (byLang.isNotEmpty) return byLang.first;

    // 2. Country-based fallback when the language has no translation entry.
    if (country != null) {
      final editionId = _countryFallbacks[country];
      if (editionId != null) {
        final edition = findById(editionId);
        if (edition != null) return edition;
      }
    }

    // 3. Default to English.
    return all.first;
  }

  /// ISO 3166-1 alpha-2 country code → edition id.
  /// Used by [forFullLocale] when the device language has no direct match.
  /// Only references edition ids present in [all].
  static const Map<String, String> _countryFallbacks = {
    // Southeast Asia
    'ID': 'id.indonesian',
    'MY': 'ms.basmeih',
    'SG': 'ms.basmeih',
    'BN': 'ms.basmeih', // Brunei
    'TH': 'th.thai',
    // South Asia
    'PK': 'ur.maududi',
    'BD': 'bn.bengali',
    'IN': 'en.sahih', // diverse; English is safest neutral default
    // Arab world
    'SA': 'ar.muyassar',
    'AE': 'ar.muyassar',
    'EG': 'ar.muyassar',
    'KW': 'ar.muyassar',
    'QA': 'ar.muyassar',
    'BH': 'ar.muyassar',
    'OM': 'ar.muyassar',
    'JO': 'ar.muyassar',
    'IQ': 'ar.muyassar',
    'LB': 'ar.muyassar',
    'SY': 'ar.muyassar',
    'MA': 'ar.muyassar',
    'TN': 'ar.muyassar',
    'DZ': 'ar.muyassar',
    'LY': 'ar.muyassar',
    'SD': 'ar.muyassar',
    'YE': 'ar.muyassar',
    // Eurasia / Central Asia
    'IR': 'fa.makarem',
    'TR': 'tr.diyanet',
    'RU': 'ru.kuliev',
    'KZ': 'ru.kuliev', // Russian widely spoken in Kazakhstan
    'UZ': 'ru.kuliev', // Russian fallback for Uzbekistan (no Uzbek entry)
    'AZ': 'ru.kuliev', // Russian fallback for Azerbaijan
    // East Asia
    'CN': 'zh.jian',
    'TW': 'zh.jian',
    'HK': 'zh.jian',
    // West Africa
    'NG': 'ha.gumi',
    'NE': 'ha.gumi',
    // East Africa
    'SO': 'so.abduh',
    'TZ': 'sw.barwani',
    'KE': 'sw.barwani',
    // Europe
    'BA': 'bs.korkut', // Bosnia — Serbian speakers use Bosnian edition
    'HR': 'bs.korkut', // Croatia — closest available
    'RS': 'bs.korkut', // Serbia — closest available
    'AL': 'sq.nahi',
    'XK': 'sq.nahi', // Kosovo
    'FR': 'fr.hamidullah',
    'BE': 'fr.hamidullah',
    'DE': 'de.aburida',
    'AT': 'de.aburida',
    'CH': 'de.aburida',
    'NL': 'nl.keyzer',
  };

  /// Finds an edition by its [id], or returns English as fallback.
  static TranslationEdition? findById(String id) {
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
