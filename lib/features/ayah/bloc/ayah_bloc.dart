import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/result/result.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/translation.dart';
import '../../../data/models/translation_edition.dart';
import '../../../data/repositories/ayah_repository.dart';
import '../../../data/repositories/settings_repository.dart';

// ---------- Events ----------

sealed class AyahEvent extends Equatable {
  const AyahEvent();
  @override
  List<Object?> get props => const [];
}

class AyahLoadRequested extends AyahEvent {
  final int surahNumber;

  /// Optional full Surah metadata — used to enrich the reader header.
  final Surah? surah;

  const AyahLoadRequested(this.surahNumber, {this.surah});
  @override
  List<Object?> get props => [surahNumber];
}

class AyahTranslationToggled extends AyahEvent {
  const AyahTranslationToggled();
}

class AyahLoadMoreRequested extends AyahEvent {
  const AyahLoadMoreRequested();
}

/// Fired by PlayerBloc listener when the position changes so the active ayah
/// can be derived from the ayah list.
class AyahPositionUpdated extends AyahEvent {
  final Duration position;
  const AyahPositionUpdated(this.position);
  @override
  List<Object?> get props => [position];
}

// ---------- State ----------

enum AyahStatus { initial, loading, ready, error }

const int _kPageSize = 20;

class AyahState extends Equatable {
  final AyahStatus status;
  final List<Ayah> ayahs;
  final List<Translation> translations;
  final int activeIndex;
  final bool showTranslation;
  final String? errorMessage;
  final int visibleCount;

  /// Surah metadata for the reader header.
  final String surahEnglishName;
  final String surahArabicName;
  final int surahNumber;
  final int totalAyahs;

  const AyahState({
    this.status = AyahStatus.initial,
    this.ayahs = const [],
    this.translations = const [],
    this.activeIndex = 0,
    this.showTranslation = false,
    this.errorMessage,
    this.visibleCount = _kPageSize,
    this.surahEnglishName = '',
    this.surahArabicName = '',
    this.surahNumber = 0,
    this.totalAyahs = 0,
  });

  List<Ayah> get visibleAyahs => ayahs.take(visibleCount).toList();
  List<Translation> get visibleTranslations =>
      translations.take(visibleCount).toList();
  bool get hasMore => visibleCount < ayahs.length;

  AyahState copyWith({
    AyahStatus? status,
    List<Ayah>? ayahs,
    List<Translation>? translations,
    int? activeIndex,
    bool? showTranslation,
    String? errorMessage,
    bool clearError = false,
    int? visibleCount,
    String? surahEnglishName,
    String? surahArabicName,
    int? surahNumber,
    int? totalAyahs,
  }) => AyahState(
    status: status ?? this.status,
    ayahs: ayahs ?? this.ayahs,
    translations: translations ?? this.translations,
    activeIndex: activeIndex ?? this.activeIndex,
    showTranslation: showTranslation ?? this.showTranslation,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    visibleCount: visibleCount ?? this.visibleCount,
    surahEnglishName: surahEnglishName ?? this.surahEnglishName,
    surahArabicName: surahArabicName ?? this.surahArabicName,
    surahNumber: surahNumber ?? this.surahNumber,
    totalAyahs: totalAyahs ?? this.totalAyahs,
  );

  @override
  List<Object?> get props => [
    status,
    ayahs,
    translations,
    activeIndex,
    showTranslation,
    errorMessage,
    visibleCount,
    surahEnglishName,
    surahArabicName,
    surahNumber,
    totalAyahs,
  ];
}

// ---------- Bloc ----------

class AyahBloc extends Bloc<AyahEvent, AyahState> {
  final IAyahRepository _repo;
  final ISettingsRepository _settings;

  AyahBloc(this._repo, this._settings) : super(const AyahState()) {
    on<AyahLoadRequested>(_onLoad);
    on<AyahTranslationToggled>(_onToggleTranslation);
    on<AyahPositionUpdated>(_onPositionUpdated);
    on<AyahLoadMoreRequested>(_onLoadMore);
  }

  Future<void> _onLoad(AyahLoadRequested event, Emitter<AyahState> emit) async {
    emit(state.copyWith(status: AyahStatus.loading, clearError: true));

    // Load settings once — reuse result for both edition and toggle preference.
    final settingsResult = await _settings.load();
    final settings = settingsResult.dataOrNull;

    final arabicEdition = settings?.arabicEditionId ?? 'quran-simple';
    final translationEdition =
        settings?.translationEditionId ??
        TranslationEditions.forLocale(
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
        ).id;
    final showTranslation = settings?.showTranslation ?? false;

    final ayahsResult = await _repo.getAyahs(
      surahNumber: event.surahNumber,
      editionId: arabicEdition,
    );

    // Exhaustive pattern match — no nullable force-unwrap.
    switch (ayahsResult) {
      case Failure(:final error):
        emit(
          state.copyWith(
            status: AyahStatus.error,
            errorMessage: error.userMessage,
          ),
        );
        return;

      case Success(:final data):
        var translations = const <Translation>[];
        if (showTranslation) {
          final tResult = await _repo.getTranslations(
            surahNumber: event.surahNumber,
            editionId: translationEdition,
          );
          translations = tResult.dataOrNull ?? const [];
        }

        final surah = event.surah;
        emit(
          state.copyWith(
            status: AyahStatus.ready,
            ayahs: data,
            translations: translations,
            showTranslation: showTranslation,
            activeIndex: 0,
            visibleCount: _kPageSize,
            clearError: true,
            surahEnglishName: surah?.englishName ?? '',
            surahArabicName: surah?.name ?? '',
            surahNumber: surah?.number ?? event.surahNumber,
            totalAyahs: surah?.numberOfAyahs ?? data.length,
          ),
        );
    }
  }

  Future<void> _onToggleTranslation(
    AyahTranslationToggled event,
    Emitter<AyahState> emit,
  ) async {
    final next = !state.showTranslation;
    emit(state.copyWith(showTranslation: next));

    // Load settings once and reuse below.
    final settingsResult = await _settings.load();
    final s = settingsResult.dataOrNull;
    if (s != null) {
      await _settings.save(s.copyWith(showTranslation: next));
    }

    // Lazy-load translations if we just turned them on and have ayahs loaded.
    if (next && state.translations.isEmpty && state.ayahs.isNotEmpty) {
      final edition =
          s?.translationEditionId ??
          TranslationEditions.forLocale(
            WidgetsBinding.instance.platformDispatcher.locale.languageCode,
          ).id;
      final tResult = await _repo.getTranslations(
        surahNumber: state.ayahs.first.surahNumber,
        editionId: edition,
      );
      emit(state.copyWith(translations: tResult.dataOrNull ?? const []));
    }
  }

  void _onPositionUpdated(AyahPositionUpdated event, Emitter<AyahState> emit) {
    if (state.ayahs.isEmpty) return;
    // Ayah boundaries are not available from the AlQuran Cloud audio endpoint,
    // so we distribute position evenly across ayahs as an approximation.
    // TODO(future): replace with real ayah timing data when available.
    emit(state.copyWith(activeIndex: 0));
  }

  void _onLoadMore(AyahLoadMoreRequested event, Emitter<AyahState> emit) {
    if (!state.hasMore) return;
    emit(
      state.copyWith(
        visibleCount: (state.visibleCount + _kPageSize).clamp(
          0,
          state.ayahs.length,
        ),
      ),
    );
  }
}
