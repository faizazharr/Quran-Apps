/// Normalizes a string for forgiving fuzzy search.
///
/// Folds common transliteration variants so the user's "al fatihah" still
/// matches "Al-Faatiha":
///   1. Lowercase.
///   2. Map common diacritics to ASCII (`ā→a`, `ḥ→h`, etc.).
///   3. Drop apostrophes and Arabic transliteration marks (`'`, `’`, `ʿ`, `ʾ`).
///   4. Strip every non-alphanumeric character (so `-`, ` `, `.` disappear).
///   5. Collapse runs of repeated letters (`faatiha` → `fatiha`).
///   6. Drop a single trailing `h` (`fatihah` → `fatiha`).
String normalizeForSearch(String input) {
  if (input.isEmpty) return '';
  var s = input.toLowerCase();
  s = s
      .replaceAll(RegExp(r'[āáàâä]'), 'a')
      .replaceAll(RegExp(r'[īíìî]'), 'i')
      .replaceAll(RegExp(r'[ūúùû]'), 'u')
      .replaceAll(RegExp(r'[ēéèê]'), 'e')
      .replaceAll(RegExp(r'[ōóòô]'), 'o')
      .replaceAll(RegExp(r'[ṣšś]'), 's')
      .replaceAll(RegExp(r'[ḥ]'), 'h')
      .replaceAll(RegExp(r'[ḍ]'), 'd')
      .replaceAll(RegExp(r'[ṭ]'), 't')
      .replaceAll(RegExp(r'[ẓ]'), 'z')
      .replaceAll(RegExp("['`’ʿʾ]"), '');
  s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
  if (s.endsWith('h') && s.length > 1) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Convenience: returns true if [haystack] contains [needle] under
/// normalized comparison (case/diacritic/punctuation insensitive).
bool fuzzyContains(String haystack, String needle) {
  final n = normalizeForSearch(needle);
  if (n.isEmpty) return true;
  return normalizeForSearch(haystack).contains(n);
}
