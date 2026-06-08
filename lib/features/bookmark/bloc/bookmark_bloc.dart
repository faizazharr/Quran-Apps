import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/result/result.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/repositories/bookmark_repository.dart';

// ---------- Events ----------

sealed class BookmarkEvent extends Equatable {
  const BookmarkEvent();
  @override
  List<Object?> get props => const [];
}

class BookmarkLoadRequested extends BookmarkEvent {
  const BookmarkLoadRequested();
}

class BookmarkAddRequested extends BookmarkEvent {
  final int surahNumber;
  final String editionId;
  final int positionMs;

  const BookmarkAddRequested({
    required this.surahNumber,
    required this.editionId,
    this.positionMs = 0,
  });

  @override
  List<Object?> get props => [surahNumber, editionId, positionMs];
}

class BookmarkDeleteRequested extends BookmarkEvent {
  final int id;
  const BookmarkDeleteRequested(this.id);
  @override
  List<Object?> get props => [id];
}

class BookmarkLastPlayedSaveRequested extends BookmarkEvent {
  final int surahNumber;
  final String editionId;
  final int positionMs;

  const BookmarkLastPlayedSaveRequested({
    required this.surahNumber,
    required this.editionId,
    required this.positionMs,
  });

  @override
  List<Object?> get props => [surahNumber, editionId, positionMs];
}

// ---------- State ----------

enum BookmarkStatus { initial, loading, ready, error }

class BookmarkState extends Equatable {
  final BookmarkStatus status;
  final List<Bookmark> bookmarks;
  final Bookmark? lastPlayed;
  final String? errorMessage;

  const BookmarkState({
    this.status = BookmarkStatus.initial,
    this.bookmarks = const [],
    this.lastPlayed,
    this.errorMessage,
  });

  BookmarkState copyWith({
    BookmarkStatus? status,
    List<Bookmark>? bookmarks,
    Bookmark? lastPlayed,
    bool clearLastPlayed = false,
    String? errorMessage,
    bool clearError = false,
  }) => BookmarkState(
    status: status ?? this.status,
    bookmarks: bookmarks ?? this.bookmarks,
    lastPlayed: clearLastPlayed ? null : (lastPlayed ?? this.lastPlayed),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  @override
  List<Object?> get props => [status, bookmarks, lastPlayed, errorMessage];
}

// ---------- Bloc ----------

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final IBookmarkRepository _repo;

  BookmarkBloc(this._repo) : super(const BookmarkState()) {
    on<BookmarkLoadRequested>(_onLoad);
    on<BookmarkAddRequested>(_onAdd);
    on<BookmarkDeleteRequested>(_onDelete);
    on<BookmarkLastPlayedSaveRequested>(_onSaveLastPlayed);
  }

  Future<void> _onLoad(
    BookmarkLoadRequested event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(state.copyWith(status: BookmarkStatus.loading, clearError: true));

    final bookmarksResult = await _repo.getBookmarks();
    final lastPlayedResult = await _repo.getLastPlayed();

    // Bookmarks failure is fatal — surface error to UI.
    switch (bookmarksResult) {
      case Failure(:final error):
        emit(
          state.copyWith(
            status: BookmarkStatus.error,
            errorMessage: error.userMessage,
          ),
        );
        return;
      case Success(:final data):
        // Last-played failure is non-fatal: show bookmarks without resume chip.
        final lastPlayed = switch (lastPlayedResult) {
          Success(:final data) => data,
          Failure() => null,
        };
        emit(
          state.copyWith(
            status: BookmarkStatus.ready,
            bookmarks: data,
            lastPlayed: lastPlayed,
            clearError: true,
          ),
        );
    }
  }

  Future<void> _onAdd(
    BookmarkAddRequested event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repo.addBookmark(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
      positionMs: event.positionMs,
    );
    result.when(
      success: (_) => add(const BookmarkLoadRequested()),
      failure: (e) => emit(
        state.copyWith(
          status: BookmarkStatus.error,
          errorMessage: e.userMessage,
        ),
      ),
    );
  }

  Future<void> _onDelete(
    BookmarkDeleteRequested event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repo.deleteBookmark(event.id);
    result.when(
      success: (_) => add(const BookmarkLoadRequested()),
      failure: (e) => emit(
        state.copyWith(
          status: BookmarkStatus.error,
          errorMessage: e.userMessage,
        ),
      ),
    );
  }

  Future<void> _onSaveLastPlayed(
    BookmarkLastPlayedSaveRequested event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repo.saveLastPlayed(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
      positionMs: event.positionMs,
    );
    // Optimistically update state on success; silently swallow on failure
    // (last-played is best-effort — a DB hiccup must not disrupt playback).
    result.when(
      success: (_) {
        final updated = Bookmark(
          surahNumber: event.surahNumber,
          editionId: event.editionId,
          positionMs: event.positionMs,
          isLastPlayed: true,
          createdAt: DateTime.now(),
        );
        emit(state.copyWith(lastPlayed: updated));
      },
      failure: (_) {},
    );
  }
}
