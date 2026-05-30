import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/core/utils/search_normalizer.dart';

void main() {
  group('normalizeForSearch', () {
    test('lowercases and strips punctuation', () {
      expect(normalizeForSearch('Al-Faatiha'), 'alfatiha');
      expect(normalizeForSearch('Al Faatiha'), 'alfatiha');
    });

    test('collapses doubled vowels and trailing h', () {
      expect(normalizeForSearch('Faatihah'), 'fatiha');
      expect(normalizeForSearch('Fatihah'), 'fatiha');
      expect(normalizeForSearch('fatiha'), 'fatiha');
    });

    test('folds common diacritics', () {
      expect(normalizeForSearch('Ḥusary'), 'husary');
      expect(normalizeForSearch('Mishʿary'), 'mishary');
    });

    test('empty input returns empty', () {
      expect(normalizeForSearch(''), '');
    });
  });

  group('fuzzyContains', () {
    test('matches "al fatihah" against "Al-Faatiha"', () {
      expect(fuzzyContains('Al-Faatiha', 'al fatihah'), isTrue);
    });

    test('matches "fatiha" against "Al-Faatiha"', () {
      expect(fuzzyContains('Al-Faatiha', 'fatiha'), isTrue);
    });

    test('matches "ikhlas" against "Al-Ikhlaas"', () {
      expect(fuzzyContains('Al-Ikhlaas', 'ikhlas'), isTrue);
    });

    test('does not match unrelated text', () {
      expect(fuzzyContains('Al-Faatiha', 'zumar'), isFalse);
    });

    test('empty needle matches anything', () {
      expect(fuzzyContains('anything', ''), isTrue);
    });
  });
}
