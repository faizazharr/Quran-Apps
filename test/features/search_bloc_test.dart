import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_apps/core/errors/app_exception.dart';
import 'package:quran_apps/core/result/result.dart';
import 'package:quran_apps/data/models/edition.dart';
import 'package:quran_apps/data/models/surah.dart';
import 'package:quran_apps/data/repositories/quran_repository.dart';
import 'package:quran_apps/features/search/bloc/search_bloc.dart';

class MockQuranRepository extends Mock implements IQuranRepository {}

const _surah1 = Surah(
  number: 1,
  name: 'الفاتحة',
  englishName: 'Al-Fatihah',
  englishNameTranslation: 'The Opening',
  numberOfAyahs: 7,
  revelationType: 'Meccan',
);

const _surah2 = Surah(
  number: 2,
  name: 'البقرة',
  englishName: 'Al-Baqarah',
  englishNameTranslation: 'The Cow',
  numberOfAyahs: 286,
  revelationType: 'Medinan',
);

const _reciter = Edition(
  identifier: 'ar.alafasy',
  language: 'ar',
  name: 'Mishary Alafasy',
  englishName: 'Mishary Alafasy',
  format: 'audio',
  type: 'versebyverse',
);

void main() {
  late MockQuranRepository repo;

  setUp(() {
    repo = MockQuranRepository();
    when(
      () => repo.getReciters(),
    ).thenAnswer((_) async => const Success([_reciter]));
    when(
      () => repo.getSurahs(),
    ).thenAnswer((_) async => const Success([_surah1, _surah2]));
    when(
      () => repo.searchSurahs(any()),
    ).thenAnswer((_) async => const Success([_surah1]));
  });

  group('SearchBloc — SearchLoadRequested', () {
    blocTest<SearchBloc, SearchState>(
      'emits loading then success with surahs and reciters',
      build: () => SearchBloc(repo),
      act: (bloc) => bloc.add(const SearchLoadRequested()),
      expect: () => [
        const SearchState(status: SearchStatus.loading),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.success)
            .having((s) => s.surahs, 'surahs', [_surah1, _surah2])
            .having((s) => s.reciters, 'reciters', [_reciter])
            .having((s) => s.selectedReciter, 'selectedReciter', _reciter),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'emits failure when repository returns error',
      build: () {
        when(
          () => repo.getSurahs(),
        ).thenAnswer((_) async => const Failure(RemoteException('err')));
        return SearchBloc(repo);
      },
      act: (bloc) => bloc.add(const SearchLoadRequested()),
      expect: () => [
        const SearchState(status: SearchStatus.loading),
        isA<SearchState>().having(
          (s) => s.status,
          'status',
          SearchStatus.failure,
        ),
      ],
    );
  });

  group('SearchBloc — SearchLoadMoreRequested', () {
    blocTest<SearchBloc, SearchState>(
      'increments visibleCount by pageSize',
      build: () => SearchBloc(repo),
      seed: () => SearchState(
        status: SearchStatus.success,
        surahs: List.generate(
          50,
          (i) => Surah(
            number: i + 1,
            name: 'S$i',
            englishName: 'Surah$i',
            englishNameTranslation: 'T$i',
            numberOfAyahs: 7,
            revelationType: 'Meccan',
          ),
        ),
        visibleCount: SearchState.pageSize,
      ),
      act: (bloc) => bloc.add(const SearchLoadMoreRequested()),
      expect: () => [
        isA<SearchState>().having(
          (s) => s.visibleCount,
          'visibleCount',
          SearchState.pageSize * 2,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'does nothing when all items already visible',
      build: () => SearchBloc(repo),
      seed: () => const SearchState(
        status: SearchStatus.success,
        surahs: [_surah1],
        visibleCount: SearchState.pageSize,
      ),
      act: (bloc) => bloc.add(const SearchLoadMoreRequested()),
      expect: () => <SearchState>[],
    );
  });

  group('SearchBloc — SearchReciterChanged', () {
    blocTest<SearchBloc, SearchState>(
      'updates selectedReciter',
      build: () => SearchBloc(repo),
      seed: () => const SearchState(status: SearchStatus.success),
      act: (bloc) => bloc.add(const SearchReciterChanged(_reciter)),
      expect: () => [
        isA<SearchState>().having(
          (s) => s.selectedReciter,
          'selectedReciter',
          _reciter,
        ),
      ],
    );
  });
}
