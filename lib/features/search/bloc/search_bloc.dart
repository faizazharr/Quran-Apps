import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/edition.dart';
import '../../../data/models/surah.dart';
import '../../../data/repositories/quran_repository.dart';

// ---------- Events ----------

sealed class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => const [];
}

class SearchLoadRequested extends SearchEvent {
  const SearchLoadRequested();
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class SearchRefreshRequested extends SearchEvent {
  const SearchRefreshRequested();
}

class SearchReciterChanged extends SearchEvent {
  final Edition reciter;
  const SearchReciterChanged(this.reciter);
  @override
  List<Object?> get props => [reciter];
}

/// Emitted by the list when the user scrolls near the end — reveals the
/// next page of surahs without rebuilding the entire list.
class SearchLoadMoreRequested extends SearchEvent {
  const SearchLoadMoreRequested();
}

// ---------- State ----------

enum SearchStatus { initial, loading, refreshing, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final List<Surah> surahs;
  final List<Edition> reciters;
  final Edition? selectedReciter;
  final String? errorMessage;
  final int visibleCount;

  /// Page size for incremental rendering. Items beyond [visibleCount] are
  /// kept in [surahs] but not built by the list — they appear as the user
  /// scrolls past the current threshold.
  static const int pageSize = 20;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.surahs = const [],
    this.reciters = const [],
    this.selectedReciter,
    this.errorMessage,
    this.visibleCount = pageSize,
  });

  bool get hasResults => surahs.isNotEmpty;
  bool get isBusy =>
      status == SearchStatus.loading || status == SearchStatus.refreshing;

  /// Slice of [surahs] that should actually be rendered right now.
  List<Surah> get visibleSurahs =>
      surahs.length <= visibleCount ? surahs : surahs.sublist(0, visibleCount);

  bool get hasMore => visibleCount < surahs.length;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Surah>? surahs,
    List<Edition>? reciters,
    Edition? selectedReciter,
    String? errorMessage,
    int? visibleCount,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      surahs: surahs ?? this.surahs,
      reciters: reciters ?? this.reciters,
      selectedReciter: selectedReciter ?? this.selectedReciter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      visibleCount: visibleCount ?? this.visibleCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    surahs,
    reciters,
    selectedReciter,
    errorMessage,
    visibleCount,
  ];
}

// ---------- Bloc ----------

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final IQuranRepository _repository;
  Timer? _debounce;

  static const Duration _debounceDelay = Duration(milliseconds: 250);

  SearchBloc(this._repository) : super(const SearchState()) {
    on<SearchLoadRequested>(_onStarted);
    on<SearchRefreshRequested>(_onRefreshed);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchReciterChanged>(_onReciterChanged);
    on<SearchLoadMoreRequested>(_onLoadMore);
  }

  Future<void> _onStarted(
    SearchLoadRequested event,
    Emitter<SearchState> emit,
  ) => _load(emit, status: SearchStatus.loading);

  Future<void> _onRefreshed(
    SearchRefreshRequested event,
    Emitter<SearchState> emit,
  ) => _load(emit, status: SearchStatus.refreshing);

  Future<void> _load(
    Emitter<SearchState> emit, {
    required SearchStatus status,
  }) async {
    emit(state.copyWith(status: status, clearError: true));

    final recResult = await _repository.getReciters();
    final reciters = recResult.when(
      success: (list) => list,
      failure: (_) => const <Edition>[],
    );

    final q = state.query.trim();
    final surahsResult = q.isEmpty
        ? await _repository.getSurahs()
        : await _repository.searchSurahs(q);

    surahsResult.when(
      success: (surahs) {
        final picked =
            state.selectedReciter ??
            (reciters.isNotEmpty ? reciters.first : null);
        emit(
          state.copyWith(
            status: SearchStatus.success,
            surahs: surahs,
            reciters: reciters,
            selectedReciter: picked,
            visibleCount: SearchState.pageSize,
            clearError: true,
          ),
        );
      },
      failure: (error) => emit(
        state.copyWith(
          status: SearchStatus.failure,
          errorMessage: error.userMessage,
          reciters: reciters,
        ),
      ),
    );
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(query: event.query));

    _debounce?.cancel();
    final completer = Completer<void>();

    _debounce = Timer(_debounceDelay, () async {
      try {
        final result = await _repository.searchSurahs(event.query);
        if (!emit.isDone) {
          result.when(
            success: (surahs) => emit(
              state.copyWith(
                status: SearchStatus.success,
                surahs: surahs,
                visibleCount: SearchState.pageSize,
                clearError: true,
              ),
            ),
            failure: (error) => emit(
              state.copyWith(
                status: SearchStatus.failure,
                errorMessage: error.userMessage,
              ),
            ),
          );
        }
      } finally {
        // Always complete so the event handler never hangs — even if the
        // repository throws an unexpected exception.
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future;
  }

  void _onReciterChanged(
    SearchReciterChanged event,
    Emitter<SearchState> emit,
  ) {
    emit(state.copyWith(selectedReciter: event.reciter));
  }

  void _onLoadMore(SearchLoadMoreRequested event, Emitter<SearchState> emit) {
    if (!state.hasMore) return;
    final next = (state.visibleCount + SearchState.pageSize).clamp(
      0,
      state.surahs.length,
    );
    emit(state.copyWith(visibleCount: next));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
