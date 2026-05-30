import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/core/errors/app_exception.dart';
import 'package:quran_apps/core/network/connectivity_service.dart';
import 'package:quran_apps/data/datasources/quran_local_data_source.dart';
import 'package:quran_apps/data/datasources/quran_remote_data_source.dart';
import 'package:quran_apps/data/models/edition.dart';
import 'package:quran_apps/data/models/surah.dart';
import 'package:quran_apps/data/repositories/quran_repository_impl.dart';

class _FakeRemote implements IQuranRemoteDataSource {
  final List<Surah> surahs;
  final List<Edition> editions;
  int surahCalls = 0;
  int editionCalls = 0;
  _FakeRemote({this.surahs = const [], this.editions = const []});

  @override
  Future<List<Surah>> fetchSurahs() async {
    surahCalls++;
    return surahs;
  }

  @override
  Future<List<Edition>> fetchAudioEditions() async {
    editionCalls++;
    return editions;
  }
}

class _FakeLocal implements IQuranLocalDataSource {
  List<Surah> surahs;
  List<Edition> editions;
  _FakeLocal({this.surahs = const [], this.editions = const []});

  @override
  Future<List<Surah>> getSurahs() async => surahs;

  @override
  Future<List<Edition>> getEditions() async => editions;

  @override
  Future<void> cacheSurahs(List<Surah> data) async => surahs = data;

  @override
  Future<void> cacheEditions(List<Edition> data) async => editions = data;

  @override
  Future<bool> hasCachedData() async =>
      surahs.isNotEmpty && editions.isNotEmpty;
}

class _FakeConnectivity implements IConnectivityService {
  final bool online;
  const _FakeConnectivity(this.online);
  @override
  Future<bool> isConnected() async => online;
}

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
    name: '',
    englishName: 'Mishary Alafasy',
    format: 'audio',
    type: 'versebyverse',
  );

  group('QuranRepositoryImpl (Result API)', () {
    test('Success: serves from local cache when available', () async {
      final remote = _FakeRemote();
      final local = _FakeLocal(surahs: [surah], editions: [edition]);
      final repo = QuranRepositoryImpl(
        remote: remote,
        local: local,
        connectivity: const _FakeConnectivity(false),
      );

      final result = await repo.getTracks();
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, hasLength(1));
      expect(remote.surahCalls, 0);
    });

    test(
      'Success: fetches from remote and caches when local empty + online',
      () async {
        final remote = _FakeRemote(surahs: [surah], editions: [edition]);
        final local = _FakeLocal();
        final repo = QuranRepositoryImpl(
          remote: remote,
          local: local,
          connectivity: const _FakeConnectivity(true),
        );

        final result = await repo.getTracks();
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, hasLength(1));
        expect(local.surahs, hasLength(1));
        expect(local.editions, hasLength(1));
      },
    );

    test('Failure: OfflineException when offline + cache empty', () async {
      final repo = QuranRepositoryImpl(
        remote: _FakeRemote(),
        local: _FakeLocal(),
        connectivity: const _FakeConnectivity(false),
      );
      final result = await repo.getTracks();
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<OfflineException>());
    });

    test('Success: search filters cached tracks', () async {
      const otherSurah = Surah(
        number: 2,
        name: 'البقرة',
        englishName: 'Al-Baqarah',
        englishNameTranslation: 'The Cow',
        numberOfAyahs: 286,
        revelationType: 'Medinan',
      );
      final local = _FakeLocal(
        surahs: [surah, otherSurah],
        editions: [edition],
      );
      final repo = QuranRepositoryImpl(
        remote: _FakeRemote(),
        local: local,
        connectivity: const _FakeConnectivity(false),
      );

      final result = await repo.search('baqarah');
      expect(result.isSuccess, isTrue);
      final list = result.dataOrNull!;
      expect(list, hasLength(1));
      expect(list.first.surah.number, 2);
    });
  });
}
