import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/data/models/edition.dart';
import 'package:quran_apps/data/models/surah.dart';
import 'package:quran_apps/data/models/track.dart';
import 'package:quran_apps/features/player/bloc/player_bloc.dart';

void main() {
  const surah = Surah(
    number: 2,
    name: 'البقرة',
    englishName: 'Al-Baqarah',
    englishNameTranslation: 'The Cow',
    numberOfAyahs: 286,
    revelationType: 'Medinan',
  );
  const edition = Edition(
    identifier: 'ar.alafasy',
    language: 'ar',
    name: '',
    englishName: 'Mishary Alafasy',
    format: 'audio',
    type: 'versebyverse',
  );
  const track = Track(surah: surah, edition: edition);

  test('PlayerState defaults are sensible', () {
    const state = PlayerState();
    expect(state.hasTrack, isFalse);
    expect(state.isPlaying, isFalse);
    expect(state.status, PlaybackStatus.idle);
    expect(state.position, Duration.zero);
    expect(state.duration, Duration.zero);
  });

  test('copyWith updates only specified fields and supports clearError', () {
    const initial = PlayerState(
      track: track,
      status: PlaybackStatus.error,
      errorMessage: 'boom',
    );

    final updated = initial.copyWith(
      status: PlaybackStatus.playing,
      position: const Duration(seconds: 5),
      clearError: true,
    );

    expect(updated.track, track);
    expect(updated.status, PlaybackStatus.playing);
    expect(updated.position, const Duration(seconds: 5));
    expect(updated.errorMessage, isNull);
  });

  test('isPlaying reflects status', () {
    const state = PlayerState(track: track, status: PlaybackStatus.playing);
    expect(state.isPlaying, isTrue);
  });
}
