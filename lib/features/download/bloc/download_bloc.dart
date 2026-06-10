import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/download_record.dart';
import '../../../data/services/download_service.dart';

// ---------- Events ----------

sealed class DownloadEvent extends Equatable {
  const DownloadEvent();
  @override
  List<Object?> get props => const [];
}

class DownloadLoadRequested extends DownloadEvent {
  const DownloadLoadRequested();
}

class DownloadEnqueueRequested extends DownloadEvent {
  final int surahNumber;
  final String editionId;
  final String audioUrl;

  const DownloadEnqueueRequested({
    required this.surahNumber,
    required this.editionId,
    required this.audioUrl,
  });

  @override
  List<Object?> get props => [surahNumber, editionId];
}

class DownloadCancelRequested extends DownloadEvent {
  final int surahNumber;
  final String editionId;

  const DownloadCancelRequested({
    required this.surahNumber,
    required this.editionId,
  });

  @override
  List<Object?> get props => [surahNumber, editionId];
}

class DownloadDeleteRequested extends DownloadEvent {
  final int surahNumber;
  final String editionId;

  const DownloadDeleteRequested({
    required this.surahNumber,
    required this.editionId,
  });

  @override
  List<Object?> get props => [surahNumber, editionId];
}

class _DownloadsUpdated extends DownloadEvent {
  final List<DownloadRecord> records;
  const _DownloadsUpdated(this.records);
  @override
  List<Object?> get props => [records];
}

// ---------- State ----------

enum DownloadBlocStatus { initial, ready }

class DownloadState extends Equatable {
  final DownloadBlocStatus status;
  final List<DownloadRecord> records;

  const DownloadState({
    this.status = DownloadBlocStatus.initial,
    this.records = const [],
  });

  DownloadRecord? recordFor(int surahNumber, String editionId) {
    try {
      return records.firstWhere(
        (r) => r.surahNumber == surahNumber && r.editionId == editionId,
      );
    } catch (_) {
      return null;
    }
  }

  DownloadState copyWith({
    DownloadBlocStatus? status,
    List<DownloadRecord>? records,
  }) => DownloadState(
    status: status ?? this.status,
    records: records ?? this.records,
  );

  @override
  List<Object?> get props => [status, records];
}

// ---------- Bloc ----------

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final IDownloadService _service;
  StreamSubscription<List<DownloadRecord>>? _sub;

  DownloadBloc(this._service) : super(const DownloadState()) {
    on<DownloadLoadRequested>(_onLoad);
    on<DownloadEnqueueRequested>(_onEnqueue);
    on<DownloadCancelRequested>(_onCancel);
    on<DownloadDeleteRequested>(_onDelete);
    on<_DownloadsUpdated>(_onUpdated);

    _sub = _service.downloadsStream.listen(
      (records) => add(_DownloadsUpdated(records)),
    );
  }

  Future<void> _onLoad(
    DownloadLoadRequested event,
    Emitter<DownloadState> emit,
  ) async {
    final all = await _service.getAll();
    emit(state.copyWith(status: DownloadBlocStatus.ready, records: all));
  }

  Future<void> _onEnqueue(
    DownloadEnqueueRequested event,
    Emitter<DownloadState> emit,
  ) async {
    await _service.enqueue(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
      audioUrl: event.audioUrl,
    );
  }

  Future<void> _onCancel(
    DownloadCancelRequested event,
    Emitter<DownloadState> emit,
  ) async {
    await _service.cancel(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
    );
  }

  Future<void> _onDelete(
    DownloadDeleteRequested event,
    Emitter<DownloadState> emit,
  ) async {
    await _service.delete(
      surahNumber: event.surahNumber,
      editionId: event.editionId,
    );
  }

  void _onUpdated(_DownloadsUpdated event, Emitter<DownloadState> emit) {
    emit(
      state.copyWith(status: DownloadBlocStatus.ready, records: event.records),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
