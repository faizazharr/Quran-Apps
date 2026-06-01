import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ayah.dart';
import '../../../data/models/translation.dart';
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
  const AyahLoadRequested(this.surahNumber);
  @override
  List<Object?> get props => [surahNumber];
}

class AyahTranslationToggled extends AyahEvent {
  const AyahTranslationToggled();
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

class AyahState extends Equatable {
  final AyahStatus status;
  final List<Ayah> ayahs;
  final List<Translation> translations;
  final int activeIndex;
  final bool showTranslation;
  final String? errorMessage;

  const AyahState({
    this.status = AyahStatus.initial,
    this.ayahs = const [],
    this.translations = const [],
    this.activeIndex = 0,
    this.showTranslation = false,
    this.errorMessage,
  });

  AyahState copyWith({
    AyahStatus? status,
    List<Ayah>? ayahs,
    List<Translation>? translations,
    int? activeIndex,
    bool? showTranslation,
    String? errorMessage,
    bool clearError = false,
  }) => AyahState(
    status: status ?? this.status,
    ayahs: ayahs ?? this.ayahs,
    translations: translations ?? this.translations,
    activeIndex: activeIndex ?? this.activeIndex,
    showTranslation: showTranslation ?? this.showTranslation,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  @override
  List<Object?> get props => [
    status,
    ayahs,
    translations,
    activeIndex,
    showTranslation,
    errorMessage,
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
  }

  Future<void> _onLoad(AyahLoadRequested event, Emitter<AyahState> emit) async {
    emit(state.copyWith(status: AyahStatus.loading, clearError: true));

    final settingsResult = await _settings.load();
    final settings = settingsResult.dataOrNull;

    final arabicEdition = settings?.arabicEditionId ?? 'quran-simple';
    final translationEdition =
        settings?.translationEditionId ?? 'id.indonesian';
    final showTranslation = settings?.showTranslation ?? false;

    final ayahsResult = await _repo.getAyahs(
      surahNumber: event.surahNumber,
      editionId: arabicEdition,
    );

    if (ayahsResult.isFailure) {
      emit(
        state.copyWith(
          status: AyahStatus.error,
          errorMessage: ayahsResult.errorOrNull!.userMessage,
        ),
      );
      return;
    }

    List<Translation> translations = const [];
    if (showTranslation) {
      final tResult = await _repo.getTranslations(
        surahNumber: event.surahNumber,
        editionId: translationEdition,
      );
      translations = tResult.dataOrNull ?? const [];
    }

    emit(
      state.copyWith(
        status: AyahStatus.ready,
        ayahs: ayahsResult.dataOrNull!,
        translations: translations,
        showTranslation: showTranslation,
        activeIndex: 0,
        clearError: true,
      ),
    );
  }

  Future<void> _onToggleTranslation(
    AyahTranslationToggled event,
    Emitter<AyahState> emit,
  ) async {
    final next = !state.showTranslation;
    emit(state.copyWith(showTranslation: next));

    // Save preference.
    final settingsResult = await _settings.load();
    final s = settingsResult.dataOrNull;
    if (s != null) {
      await _settings.save(s.copyWith(showTranslation: next));
    }

    // Lazy-load translations if we just turned them on and have ayahs loaded.
    if (next && state.translations.isEmpty && state.ayahs.isNotEmpty) {
      final settingsResult2 = await _settings.load();
      final edition =
          settingsResult2.dataOrNull?.translationEditionId ?? 'id.indonesian';
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
}
