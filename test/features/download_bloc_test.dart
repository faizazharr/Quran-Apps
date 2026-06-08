import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_apps/data/models/download_record.dart' as record_lib;
import 'package:quran_apps/data/services/download_service.dart';
import 'package:quran_apps/features/download/bloc/download_bloc.dart' as bloc_lib;

class MockDownloadService extends Mock implements IDownloadService {}

record_lib.DownloadRecord _record({
  int surah = 1,
  String edition = 'ar.alafasy',
  record_lib.DownloadStatus status = record_lib.DownloadStatus.completed,
}) => record_lib.DownloadRecord(
  surahNumber: surah,
  editionId: edition,
  status: status,
  progress: status == record_lib.DownloadStatus.completed ? 1.0 : 0.0,
  updatedAt: DateTime(2026),
);

void main() {
  late MockDownloadService service;
  late StreamController<List<record_lib.DownloadRecord>> streamController;

  setUp(() {
    service = MockDownloadService();
    streamController =
        StreamController<List<record_lib.DownloadRecord>>.broadcast();
    when(() => service.downloadsStream)
        .thenAnswer((_) => streamController.stream);
    when(() => service.getAll()).thenAnswer((_) async => []);
    when(
      () => service.enqueue(
        surahNumber: any(named: 'surahNumber'),
        editionId: any(named: 'editionId'),
        audioUrl: any(named: 'audioUrl'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.cancel(
        surahNumber: any(named: 'surahNumber'),
        editionId: any(named: 'editionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.delete(
        surahNumber: any(named: 'surahNumber'),
        editionId: any(named: 'editionId'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() => streamController.close());

  group('DownloadBloc — DownloadLoadRequested', () {
    blocTest<bloc_lib.DownloadBloc, bloc_lib.DownloadState>(
      'emits ready with records returned by service',
      build: () {
        when(() => service.getAll()).thenAnswer((_) async => [_record()]);
        return bloc_lib.DownloadBloc(service);
      },
      act: (bloc) => bloc.add(const bloc_lib.DownloadLoadRequested()),
      expect: () => [
        isA<bloc_lib.DownloadState>()
            .having(
              (s) => s.status,
              'status',
              bloc_lib.DownloadBlocStatus.ready,
            )
            .having((s) => s.records.length, 'records.length', 1),
      ],
    );
  });

  group('DownloadBloc — stream updates', () {
    blocTest<bloc_lib.DownloadBloc, bloc_lib.DownloadState>(
      'reflects incoming stream events in state',
      build: () => bloc_lib.DownloadBloc(service),
      act: (bloc) {
        streamController
            .add([_record(status: record_lib.DownloadStatus.downloading)]);
      },
      expect: () => [
        isA<bloc_lib.DownloadState>().having(
          (s) => s.records.first.status,
          'records.first.status',
          record_lib.DownloadStatus.downloading,
        ),
      ],
    );
  });

  group('DownloadBloc — DownloadEnqueueRequested', () {
    blocTest<bloc_lib.DownloadBloc, bloc_lib.DownloadState>(
      'calls service.enqueue with correct arguments',
      build: () => bloc_lib.DownloadBloc(service),
      act: (bloc) => bloc.add(
        const bloc_lib.DownloadEnqueueRequested(
          surahNumber: 2,
          editionId: 'ar.alafasy',
          audioUrl: 'https://cdn.example.com/2.mp3',
        ),
      ),
      verify: (_) {
        verify(
          () => service.enqueue(
            surahNumber: 2,
            editionId: 'ar.alafasy',
            audioUrl: 'https://cdn.example.com/2.mp3',
          ),
        ).called(1);
      },
    );
  });

  group('DownloadBloc — DownloadDeleteRequested', () {
    blocTest<bloc_lib.DownloadBloc, bloc_lib.DownloadState>(
      'calls service.delete with correct arguments',
      build: () => bloc_lib.DownloadBloc(service),
      act: (bloc) => bloc.add(
        const bloc_lib.DownloadDeleteRequested(
          surahNumber: 1,
          editionId: 'ar.alafasy',
        ),
      ),
      verify: (_) {
        verify(
          () => service.delete(surahNumber: 1, editionId: 'ar.alafasy'),
        ).called(1);
      },
    );
  });

  group('DownloadBloc — DownloadCancelRequested', () {
    blocTest<bloc_lib.DownloadBloc, bloc_lib.DownloadState>(
      'calls service.cancel with correct arguments',
      build: () => bloc_lib.DownloadBloc(service),
      act: (bloc) => bloc.add(
        const bloc_lib.DownloadCancelRequested(
          surahNumber: 3,
          editionId: 'ar.alafasy',
        ),
      ),
      verify: (_) {
        verify(
          () => service.cancel(surahNumber: 3, editionId: 'ar.alafasy'),
        ).called(1);
      },
    );
  });
}
