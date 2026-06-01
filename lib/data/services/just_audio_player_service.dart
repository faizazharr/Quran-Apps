import 'dart:io';

// ignore_for_file: experimental_member_use, avoid_slow_async_io
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'audio_player_service.dart';

/// `just_audio`-backed implementation with background playback support via
/// `just_audio_background`.
///
/// * Uses [LockCachingAudioSource] so any track that has been streamed once is
///   cached on device and replayable while offline.
/// * Exposes lock-screen / notification controls through [MediaItem] metadata.
class JustAudioPlayerService implements IAudioPlayerService {
  final AudioPlayer _player;
  Directory? _cacheDir;

  JustAudioPlayerService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'audio_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  @override
  Future<void> load(Track track) async {
    final dir = await _ensureCacheDir();
    final cacheFile = File(p.join(dir.path, '${track.id}.mp3'));

    await _player.stop();

    // Wrap in MediaItem so just_audio_background can populate the OS
    // notification / lock screen with surah name and reciter.
    final mediaItem = MediaItem(
      id: track.id,
      title: track.surah.englishName,
      artist: track.artist,
      album: 'Quran Player',
      extras: {'surahNumber': track.surah.number},
    );

    try {
      await _player.setAudioSource(
        LockCachingAudioSource(
          Uri.parse(track.audioUrl),
          cacheFile: cacheFile,
          tag: mediaItem,
        ),
      );
    } catch (_) {
      // Fallback to plain network source (no offline cache for this attempt).
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(track.audioUrl), tag: mediaItem),
      );
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<AudioPlaybackSnapshot> get playbackStream =>
      _player.playerStateStream.map(
        (s) => AudioPlaybackSnapshot(
          playing: s.playing,
          buffering:
              s.processingState == ProcessingState.loading ||
              s.processingState == ProcessingState.buffering,
          completed: s.processingState == ProcessingState.completed,
        ),
      );
}
