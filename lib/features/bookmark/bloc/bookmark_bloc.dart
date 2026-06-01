import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class BookmarkLastPlayedSaved extends BookmarkEvent {
  final int surahNumber;
  final String editionId;
  final int positionMs;

  const BookmarkLastPlayedSaved({
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
    on<BookmarkLastPlayedSaved>(_onSaveLastPlayed);
  }

  Future<void> _onLoad(
    BookmarkLoadRequested event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(state.copyWith(status: BookmarkStatus.loading, clearError: true));
    final bookmarksResult = await _repo.getBookmarks();
    final lastPlayedResult = await _repo.getLastPlayed();

    final bookmarks = bookmarksResult.dataOrNull ?? const [];
    final lastPlayed = lastPlayedResult.dataOrNull;
    final error = bookmarksResult.errorOrNull ?? lastPlayedResult.errorOrNull;

    emit(
      state.copyWith(
        status: error == null ? BookmarkStatus.ready : BookmarkStatus.error,
        bookmarks: bookmarks,
        lastPlayed: lastPlayed,
        errorMessage: error?.userMessage,
      ),
    );
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
    if (result.isSuccess) {
      add(const BookmarkLoadRequested());
    }
  }

  Future<void> _onDelete(
    BookmarkDeleteRequested event,
    Emitter<BookmarkState> emit,
  ) async {
    await _repo.deleteBookmark(event.id);
    add(const BookmarkLoadRequested());
  }

  Future<void> _onSaveLastPlayed(
    BookmarkLastPlayedSaved event,
    Emitter<BookmarkState> emit,
  ) async {
    await _repo.saveLastPlayed(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
      positionMs: event.positionMs,
    );
    // Optimistically update state without a full reload.
    final updated = Bookmark(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
      positionMs: event.positionMs,
      isLastPlayed: true,
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(lastPlayed: updated));
  }
}
