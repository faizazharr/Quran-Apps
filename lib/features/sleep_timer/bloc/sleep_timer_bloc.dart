import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ---------- Events ----------

sealed class SleepTimerEvent extends Equatable {
  const SleepTimerEvent();
  @override
  List<Object?> get props => const [];
}

class SleepTimerStarted extends SleepTimerEvent {
  final SleepTimerOption option;
  const SleepTimerStarted(this.option);
  @override
  List<Object?> get props => [option];
}

class SleepTimerCancelled extends SleepTimerEvent {
  const SleepTimerCancelled();
}

/// Internal — fired by the periodic tick.
class _SleepTimerTicked extends SleepTimerEvent {
  const _SleepTimerTicked();
}

// ---------- Domain types ----------

/// Pre-defined sleep timer options shown in the UI.
enum SleepTimerOption {
  min15(minutes: 15),
  min30(minutes: 30),
  min45(minutes: 45),
  min60(minutes: 60),

  /// Special: expire when the current surah finishes. The caller is
  /// responsible for firing [SleepTimerCancelled] when playback completes.
  endOfSurah(minutes: null);

  final int? minutes;
  const SleepTimerOption({required this.minutes});
}

// ---------- State ----------

enum SleepTimerStatus { idle, active, expired }

class SleepTimerState extends Equatable {
  final SleepTimerStatus status;
  final SleepTimerOption? option;

  /// Remaining duration. Null when idle or [SleepTimerOption.endOfSurah].
  final Duration? remaining;

  const SleepTimerState({
    this.status = SleepTimerStatus.idle,
    this.option,
    this.remaining,
  });

  bool get isActive => status == SleepTimerStatus.active;
  bool get isEndOfSurah => option == SleepTimerOption.endOfSurah;

  SleepTimerState copyWith({
    SleepTimerStatus? status,
    SleepTimerOption? option,
    Duration? remaining,
    bool clearRemaining = false,
  }) => SleepTimerState(
    status: status ?? this.status,
    option: option ?? this.option,
    remaining: clearRemaining ? null : (remaining ?? this.remaining),
  );

  @override
  List<Object?> get props => [status, option, remaining];
}

// ---------- Bloc ----------

class SleepTimerBloc extends Bloc<SleepTimerEvent, SleepTimerState> {
  Timer? _ticker;

  SleepTimerBloc() : super(const SleepTimerState()) {
    on<SleepTimerStarted>(_onStarted);
    on<SleepTimerCancelled>(_onCancelled);
    on<_SleepTimerTicked>(_onTicked);
  }

  void _onStarted(SleepTimerStarted event, Emitter<SleepTimerState> emit) {
    _ticker?.cancel();
    _ticker = null;

    final option = event.option;

    if (option == SleepTimerOption.endOfSurah) {
      emit(
        SleepTimerState(
          status: SleepTimerStatus.active,
          option: option,
          remaining: null,
        ),
      );
      return;
    }

    final duration = Duration(minutes: option.minutes!);
    emit(
      SleepTimerState(
        status: SleepTimerStatus.active,
        option: option,
        remaining: duration,
      ),
    );

    // Tick every second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const _SleepTimerTicked());
    });
  }

  void _onCancelled(SleepTimerCancelled event, Emitter<SleepTimerState> emit) {
    _ticker?.cancel();
    _ticker = null;
    emit(const SleepTimerState());
  }

  void _onTicked(_SleepTimerTicked event, Emitter<SleepTimerState> emit) {
    final remaining = state.remaining;
    if (remaining == null) return;

    final next = remaining - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      emit(
        state.copyWith(status: SleepTimerStatus.expired, clearRemaining: true),
      );
    } else {
      emit(state.copyWith(remaining: next));
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
