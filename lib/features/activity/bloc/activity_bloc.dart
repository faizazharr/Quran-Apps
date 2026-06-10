import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/activity_repository.dart';

// ─────────────────────────── Events ─────────────────────────────────────────

sealed class ActivityEvent extends Equatable {
  const ActivityEvent();
  @override
  List<Object?> get props => const [];
}

/// Load persisted timestamps from storage on startup.
class ActivityLoadRequested extends ActivityEvent {
  const ActivityLoadRequested();
}

/// Record that the user opened a surah to read.
class ActivityReadRecorded extends ActivityEvent {
  final DateTime at;
  const ActivityReadRecorded(this.at);
  @override
  List<Object?> get props => [at];
}

/// Record that the user started listening to audio.
class ActivityListenedRecorded extends ActivityEvent {
  final DateTime at;
  const ActivityListenedRecorded(this.at);
  @override
  List<Object?> get props => [at];
}

// ─────────────────────────── State ──────────────────────────────────────────

class ActivityState extends Equatable {
  final DateTime? lastReadAt;
  final DateTime? lastListenedAt;

  const ActivityState({this.lastReadAt, this.lastListenedAt});

  bool get hasActivity => lastReadAt != null || lastListenedAt != null;

  ActivityState copyWith({DateTime? lastReadAt, DateTime? lastListenedAt}) =>
      ActivityState(
        lastReadAt: lastReadAt ?? this.lastReadAt,
        lastListenedAt: lastListenedAt ?? this.lastListenedAt,
      );

  @override
  List<Object?> get props => [lastReadAt, lastListenedAt];
}

// ─────────────────────────── BLoC ────────────────────────────────────────────

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final IActivityRepository _repo;

  ActivityBloc(this._repo) : super(const ActivityState()) {
    on<ActivityLoadRequested>(_onLoad);
    on<ActivityReadRecorded>(_onReadRecorded);
    on<ActivityListenedRecorded>(_onListenedRecorded);
  }

  Future<void> _onLoad(
    ActivityLoadRequested event,
    Emitter<ActivityState> emit,
  ) async {
    final activity = await _repo.load();
    emit(
      ActivityState(
        lastReadAt: activity.lastReadAt,
        lastListenedAt: activity.lastListenedAt,
      ),
    );
  }

  Future<void> _onReadRecorded(
    ActivityReadRecorded event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(lastReadAt: event.at));
    await _repo.saveLastRead(event.at);
  }

  Future<void> _onListenedRecorded(
    ActivityListenedRecorded event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(lastListenedAt: event.at));
    await _repo.saveLastListened(event.at);
  }
}
