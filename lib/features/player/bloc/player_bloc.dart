import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/track.dart';
import '../../../data/services/audio_player_service.dart';

// ---------- Events ----------

sealed class PlayerEvent extends Equatable {
  const PlayerEvent();
  @override
  List<Object?> get props => const [];
}

class PlayerTrackSelected extends PlayerEvent {
  final Track track;
  const PlayerTrackSelected(this.track);
  @override
  List<Object?> get props => [track];
}

class PlayerPlayRequested extends PlayerEvent {
  const PlayerPlayRequested();
}

class PlayerPauseRequested extends PlayerEvent {
  const PlayerPauseRequested();
}

class PlayerSeekRequested extends PlayerEvent {
  final Duration position;
  const PlayerSeekRequested(this.position);
  @override
  List<Object?> get props => [position];
}

class PlayerStopRequested extends PlayerEvent {
  const PlayerStopRequested();
}

class _PlayerPositionUpdated extends PlayerEvent {
  final Duration position;
  const _PlayerPositionUpdated(this.position);
  @override
  List<Object?> get props => [position];
}

class _PlayerDurationUpdated extends PlayerEvent {
  final Duration? duration;
  const _PlayerDurationUpdated(this.duration);
  @override
  List<Object?> get props => [duration];
}

class _PlayerPlaybackUpdated extends PlayerEvent {
  final AudioPlaybackSnapshot snapshot;
  const _PlayerPlaybackUpdated(this.snapshot);
  @override
  List<Object?> get props => [
    snapshot.playing,
    snapshot.buffering,
    snapshot.completed,
  ];
}

class _PlayerErrorOccurred extends PlayerEvent {
  final String message;
  const _PlayerErrorOccurred(this.message);
  @override
  List<Object?> get props => [message];
}

class PlayerSpeedChanged extends PlayerEvent {
  final double speed;
  const PlayerSpeedChanged(this.speed);
  @override
  List<Object?> get props => [speed];
}

// ---------- State ----------

enum PlaybackStatus { idle, loading, ready, playing, paused, completed, error }

class PlayerState extends Equatable {
  final Track? track;
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
  final double speed;

  const PlayerState({
    this.track,
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
    this.speed = 1.0,
  });

  bool get hasTrack => track != null;
  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isLoading => status == PlaybackStatus.loading;

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    Track? track,
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
    double? speed,
  }) {
    return PlayerState(
      track: track ?? this.track,
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      speed: speed ?? this.speed,
    );
  }

  @override
  List<Object?> get props => [
    track,
    status,
    position,
    duration,
    errorMessage,
    speed,
  ];
}

// ---------- Bloc ----------

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final IAudioPlayerService _player;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<AudioPlaybackSnapshot>? _playbackSub;

  PlayerBloc(this._player) : super(const PlayerState()) {
    on<PlayerTrackSelected>(_onTrackSelected);
    on<PlayerPlayRequested>(_onPlay);
    on<PlayerPauseRequested>(_onPause);
    on<PlayerSeekRequested>(_onSeek);
    on<PlayerStopRequested>(_onStop);
    on<PlayerSpeedChanged>(_onSpeedChanged);
    on<_PlayerPositionUpdated>(_onPositionUpdated);
    on<_PlayerDurationUpdated>(_onDurationUpdated);
    on<_PlayerPlaybackUpdated>(_onPlaybackUpdated);
    on<_PlayerErrorOccurred>(_onErrorOccurred);

    _wireStreams();
  }

  void _wireStreams() {
    _positionSub = _player.positionStream.listen(
      (p) => add(_PlayerPositionUpdated(p)),
    );
    _durationSub = _player.durationStream.listen(
      (d) => add(_PlayerDurationUpdated(d)),
    );
    _playbackSub = _player.playbackStream.listen(
      (s) => add(_PlayerPlaybackUpdated(s)),
    );
  }

  Future<void> _onTrackSelected(
    PlayerTrackSelected event,
    Emitter<PlayerState> emit,
  ) async {
    if (state.track?.id == event.track.id) {
      if (state.isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    emit(PlayerState(track: event.track, status: PlaybackStatus.loading));
    try {
      await _player.load(event.track);
      await _player.play();
    } catch (e) {
      // Surface the real reason so a 403 / network failure is visible to the
      // user instead of a generic "Playback failed" string.
      add(
        _PlayerErrorOccurred(
          PlaybackException(_describeAudioError(e)).userMessage,
        ),
      );
    }
  }

  String _describeAudioError(Object e) {
    final raw = e.toString();
    if (raw.contains('403') || raw.toLowerCase().contains('forbidden')) {
      return 'This reciter is not available for full-surah streaming.';
    }
    if (raw.contains('404')) {
      return 'Audio file not found for this surah.';
    }
    if (raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('network')) {
      return 'Network error while loading audio. Check your connection.';
    }
    return 'Unable to load audio.';
  }

  Future<void> _onPlay(
    PlayerPlayRequested event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasTrack) return;
    await _player.play();
  }

  Future<void> _onPause(
    PlayerPauseRequested event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasTrack) return;
    await _player.pause();
  }

  Future<void> _onSeek(
    PlayerSeekRequested event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasTrack) return;
    final clamped = _clampPosition(event.position, state.duration);
    await _player.seek(clamped);
    emit(state.copyWith(position: clamped));
  }

  Future<void> _onStop(
    PlayerStopRequested event,
    Emitter<PlayerState> emit,
  ) async {
    await _player.stop();
    emit(const PlayerState());
  }

  Future<void> _onSpeedChanged(
    PlayerSpeedChanged event,
    Emitter<PlayerState> emit,
  ) async {
    final speed = event.speed.clamp(0.5, 2.0);
    await _player.setSpeed(speed);
    emit(state.copyWith(speed: speed));
  }

  void _onPositionUpdated(
    _PlayerPositionUpdated event,
    Emitter<PlayerState> emit,
  ) {
    if (!state.hasTrack) return;
    emit(state.copyWith(position: event.position));
  }

  void _onDurationUpdated(
    _PlayerDurationUpdated event,
    Emitter<PlayerState> emit,
  ) {
    if (!state.hasTrack) return;
    emit(state.copyWith(duration: event.duration ?? Duration.zero));
  }

  void _onPlaybackUpdated(
    _PlayerPlaybackUpdated event,
    Emitter<PlayerState> emit,
  ) {
    if (!state.hasTrack) return;
    final s = event.snapshot;
    final PlaybackStatus next;
    if (s.completed) {
      next = PlaybackStatus.completed;
    } else if (s.buffering) {
      next = PlaybackStatus.loading;
    } else if (s.playing) {
      next = PlaybackStatus.playing;
    } else {
      next = PlaybackStatus.paused;
    }
    emit(state.copyWith(status: next, clearError: true));
  }

  void _onErrorOccurred(_PlayerErrorOccurred event, Emitter<PlayerState> emit) {
    emit(
      state.copyWith(status: PlaybackStatus.error, errorMessage: event.message),
    );
  }

  Duration _clampPosition(Duration target, Duration max) {
    if (target.isNegative) return Duration.zero;
    if (max > Duration.zero && target > max) return max;
    return target;
  }

  @override
  Future<void> close() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playbackSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
