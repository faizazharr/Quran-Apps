import 'dart:io';

// ignore_for_file: experimental_member_use, avoid_slow_async_io
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'audio_player_service.dart';

/// `just_audio`-backed implementation.
///
/// Uses [LockCachingAudioSource] so any track that has been streamed once is
/// cached on the device and replayable while offline.
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
    try {
      await _player.setAudioSource(
        LockCachingAudioSource(Uri.parse(track.audioUrl), cacheFile: cacheFile),
      );
    } catch (_) {
      // The cache-aware source can fail on some Android configurations / when
      // the CDN rejects the request. Fall back to a plain network source so
      // playback still works (without offline caching for this track). If the
      // fallback also fails, the underlying error propagates to the caller.
      await _player.setAudioSource(AudioSource.uri(Uri.parse(track.audioUrl)));
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
