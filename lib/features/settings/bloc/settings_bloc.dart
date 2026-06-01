import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/repositories/settings_repository.dart';

// ---------- Events ----------

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => const [];
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsThemeChanged extends SettingsEvent {
  final AppThemeMode themeMode;
  const SettingsThemeChanged(this.themeMode);
  @override
  List<Object?> get props => [themeMode];
}

class SettingsLocaleChanged extends SettingsEvent {
  /// BCP-47 tag (e.g. `en`, `id`). Null = follow system.
  final String? localeTag;
  const SettingsLocaleChanged(this.localeTag);
  @override
  List<Object?> get props => [localeTag];
}

class SettingsTranslationEditionChanged extends SettingsEvent {
  final String editionId;
  const SettingsTranslationEditionChanged(this.editionId);
  @override
  List<Object?> get props => [editionId];
}

// ---------- State ----------

enum SettingsStatus { initial, loading, ready, error }

class SettingsState extends Equatable {
  final SettingsStatus status;
  final AppSettings settings;
  final String? errorMessage;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.settings = AppSettings.defaults,
    this.errorMessage,
  });

  SettingsState copyWith({
    SettingsStatus? status,
    AppSettings? settings,
    String? errorMessage,
    bool clearError = false,
  }) => SettingsState(
    status: status ?? this.status,
    settings: settings ?? this.settings,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  @override
  List<Object?> get props => [status, settings, errorMessage];
}

// ---------- Bloc ----------

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final ISettingsRepository _repo;

  SettingsBloc(this._repo) : super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoad);
    on<SettingsThemeChanged>(_onThemeChanged);
    on<SettingsLocaleChanged>(_onLocaleChanged);
    on<SettingsTranslationEditionChanged>(_onTranslationEditionChanged);
  }

  Future<void> _onLoad(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));
    final result = await _repo.load();
    result.when(
      success: (s) =>
          emit(state.copyWith(status: SettingsStatus.ready, settings: s)),
      failure: (e) => emit(
        state.copyWith(
          status: SettingsStatus.error,
          errorMessage: e.userMessage,
        ),
      ),
    );
  }

  Future<void> _onThemeChanged(
    SettingsThemeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(themeMode: event.themeMode);
    emit(state.copyWith(settings: updated));
    await _repo.save(updated);
  }

  Future<void> _onLocaleChanged(
    SettingsLocaleChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      localeTag: event.localeTag,
      clearLocale: event.localeTag == null,
    );
    emit(state.copyWith(settings: updated));
    await _repo.save(updated);
  }

  Future<void> _onTranslationEditionChanged(
    SettingsTranslationEditionChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      translationEditionId: event.editionId,
    );
    emit(state.copyWith(settings: updated));
    await _repo.save(updated);
  }
}
