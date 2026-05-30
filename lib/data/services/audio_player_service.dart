import '../models/track.dart';

/// Snapshot of the audio engine state.
class AudioPlaybackSnapshot {
  final bool playing;
  final bool buffering;
  final bool completed;
  const AudioPlaybackSnapshot({
    required this.playing,
    required this.buffering,
    required this.completed,
  });
}

/// Abstraction over the underlying audio engine (`just_audio`).
///
/// Keeps the BLoC free of third-party imports (Interface Segregation +
/// Dependency Inversion) and makes it trivially fakeable in tests.
abstract class IAudioPlayerService {
  /// Loads [track] for playback. Implementations may cache the audio file
  /// on disk so previously-played tracks can be replayed offline.
  Future<void> load(Track track);

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// Sets playback speed. [speed] must be > 0; typical values: 0.75, 1.0, 1.25, 1.5, 2.0.
  Future<void> setSpeed(double speed);

  Future<void> dispose();

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<AudioPlaybackSnapshot> get playbackStream;
}
