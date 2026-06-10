import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/ticker_service.dart';

// ---------- Events ----------

sealed class SleepTimerEvent extends Equatable {
  const SleepTimerEvent();
  @override
  List<Object?> get props => const [];
}

class SleepTimerStartRequested extends SleepTimerEvent {
  final SleepTimerOption option;
  const SleepTimerStartRequested(this.option);
  @override
  List<Object?> get props => [option];
}

class SleepTimerCancelRequested extends SleepTimerEvent {
  const SleepTimerCancelRequested();
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
  /// responsible for firing [SleepTimerCancelRequested] when playback completes.
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
  final ITickerService _tickerService;
  StreamSubscription<int>? _tickSub;

  SleepTimerBloc({ITickerService? ticker})
    : _tickerService = ticker ?? TickerService(),
      super(const SleepTimerState()) {
    on<SleepTimerStartRequested>(_onStarted);
    on<SleepTimerCancelRequested>(_onCancelled);
    on<_SleepTimerTicked>(_onTicked);
  }

  void _onStarted(
    SleepTimerStartRequested event,
    Emitter<SleepTimerState> emit,
  ) {
    unawaited(_tickSub?.cancel());
    _tickSub = null;

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

    _tickSub = _tickerService.tick(const Duration(seconds: 1)).listen((_) {
      if (!isClosed) add(const _SleepTimerTicked());
    });
  }

  void _onCancelled(
    SleepTimerCancelRequested event,
    Emitter<SleepTimerState> emit,
  ) {
    unawaited(_tickSub?.cancel());
    _tickSub = null;
    _tickerService.cancel();
    emit(const SleepTimerState());
  }

  void _onTicked(_SleepTimerTicked event, Emitter<SleepTimerState> emit) {
    final remaining = state.remaining;
    if (remaining == null) return;

    final next = remaining - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      unawaited(_tickSub?.cancel());
      _tickSub = null;
      _tickerService.cancel();
      emit(
        state.copyWith(status: SleepTimerStatus.expired, clearRemaining: true),
      );
    } else {
      emit(state.copyWith(remaining: next));
    }
  }

  @override
  Future<void> close() async {
    await _tickSub?.cancel();
    _tickerService.cancel();
    return super.close();
  }
}
