import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/data/models/edition.dart';
import 'package:quran_apps/data/models/surah.dart';
import 'package:quran_apps/data/models/track.dart';

void main() {
  const surah = Surah(
    number: 1,
    name: 'الفاتحة',
    englishName: 'Al-Fatihah',
    englishNameTranslation: 'The Opening',
    numberOfAyahs: 7,
    revelationType: 'Meccan',
  );

  const edition = Edition(
    identifier: 'ar.alafasy',
    language: 'ar',
    name: 'مشاري راشد العفاسي',
    englishName: 'Mishary Rashid Alafasy',
    format: 'audio',
    type: 'versebyverse',
  );

  const track = Track(surah: surah, edition: edition);

  group('Track', () {
    test('exposes a stable id', () {
      expect(track.id, '1-ar.alafasy');
    });

    test('builds the CDN audio URL', () {
      expect(
        track.audioUrl,
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3',
      );
    });

    test('matches empty query as true', () {
      expect(track.matches(''), isTrue);
      expect(track.matches('   '), isTrue);
    });

    test('matches by english surah name (case-insensitive)', () {
      expect(track.matches('fatihah'), isTrue);
      expect(track.matches('FATIHAH'), isTrue);
    });

    test('matches by reciter name', () {
      expect(track.matches('alafasy'), isTrue);
      expect(track.matches('Mishary'), isTrue);
    });

    test('matches by translation', () {
      expect(track.matches('opening'), isTrue);
    });

    test('matches by surah number string', () {
      expect(track.matches('1'), isTrue);
    });

    test('does not match unrelated query', () {
      expect(track.matches('zzz-not-here'), isFalse);
    });
  });
}
