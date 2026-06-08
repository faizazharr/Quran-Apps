import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/quote.dart';
import '../../../data/services/quote_service.dart';

// ---------- Events ----------

sealed class QuoteEvent extends Equatable {
  const QuoteEvent();
  @override
  List<Object?> get props => const [];
}

class QuoteLoadRequested extends QuoteEvent {
  const QuoteLoadRequested();
}

class QuoteRefreshRequested extends QuoteEvent {
  const QuoteRefreshRequested();
}

class QuoteScheduleChanged extends QuoteEvent {
  final QuoteSchedule schedule;
  const QuoteScheduleChanged(this.schedule);

  @override
  List<Object?> get props => [schedule];
}

// ---------- State ----------

enum QuoteStatus { initial, loading, ready, error }

enum QuoteSchedule {
  off,
  morning, // 07:00
  evening, // 19:00
  threeDaily, // 07:00, 13:00, 19:00
  custom,
}

class QuoteState extends Equatable {
  final QuoteStatus status;
  final QuoteModel? quote;
  final QuoteSchedule schedule;
  final String? errorMessage;

  const QuoteState({
    this.status = QuoteStatus.initial,
    this.quote,
    this.schedule = QuoteSchedule.off,
    this.errorMessage,
  });

  QuoteState copyWith({
    QuoteStatus? status,
    QuoteModel? quote,
    QuoteSchedule? schedule,
    String? errorMessage,
    bool clearError = false,
  }) => QuoteState(
    status: status ?? this.status,
    quote: quote ?? this.quote,
    schedule: schedule ?? this.schedule,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  @override
  List<Object?> get props => [status, quote, schedule, errorMessage];
}

// ---------- Bloc ----------

class QuoteBloc extends Bloc<QuoteEvent, QuoteState> {
  final IQuoteService _quoteService;

  QuoteBloc(this._quoteService) : super(const QuoteState()) {
    on<QuoteLoadRequested>(_onLoad);
    on<QuoteRefreshRequested>(_onRefresh);
    on<QuoteScheduleChanged>(_onScheduleChanged);
  }

  Future<void> _onLoad(
    QuoteLoadRequested event,
    Emitter<QuoteState> emit,
  ) async {
    emit(state.copyWith(status: QuoteStatus.loading, clearError: true));
    final res = await _quoteService.getDailyQuote();
    res.when(
      success: (quote) => emit(
        state.copyWith(
          status: QuoteStatus.ready,
          quote: quote,
          clearError: true,
        ),
      ),
      failure: (err) => emit(
        state.copyWith(
          status: QuoteStatus.error,
          errorMessage: err.userMessage,
        ),
      ),
    );
  }

  Future<void> _onRefresh(
    QuoteRefreshRequested event,
    Emitter<QuoteState> emit,
  ) async {
    emit(state.copyWith(status: QuoteStatus.loading, clearError: true));
    final res = await _quoteService.fetchNewRandomQuote();
    res.when(
      success: (quote) => emit(
        state.copyWith(
          status: QuoteStatus.ready,
          quote: quote,
          clearError: true,
        ),
      ),
      failure: (err) => emit(
        state.copyWith(
          status: QuoteStatus.error,
          errorMessage: err.userMessage,
        ),
      ),
    );
  }

  void _onScheduleChanged(
    QuoteScheduleChanged event,
    Emitter<QuoteState> emit,
  ) {
    emit(state.copyWith(schedule: event.schedule));
    // Here we can trigger rescheduling of notification notifications as well
  }
}
