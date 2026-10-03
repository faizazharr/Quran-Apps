import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/tip_service.dart';

// ---------- Events ----------

sealed class TipEvent extends Equatable {
  const TipEvent();
  @override
  List<Object?> get props => const [];
}

class TipLoadRequested extends TipEvent {
  const TipLoadRequested();
}

class TipPurchaseRequested extends TipEvent {
  final TipProduct product;
  const TipPurchaseRequested(this.product);
  @override
  List<Object?> get props => [product.id];
}

class _TipServiceEvent extends TipEvent {
  final TipResult event;
  const _TipServiceEvent(this.event);
  @override
  List<Object?> get props => [event];
}

// ---------- State ----------

enum TipStatus { loading, unavailable, ready, purchasing, thanks, failed }

class TipState extends Equatable {
  final TipStatus status;
  final List<TipProduct> products;
  const TipState({this.status = TipStatus.loading, this.products = const []});

  TipState copyWith({TipStatus? status, List<TipProduct>? products}) =>
      TipState(
        status: status ?? this.status,
        products: products ?? this.products,
      );

  @override
  List<Object?> get props => [status, products.map((p) => p.id).toList()];
}

// ---------- Bloc ----------

class TipBloc extends Bloc<TipEvent, TipState> {
  final ITipService _service;
  StreamSubscription<TipResult>? _sub;

  TipBloc(this._service) : super(const TipState()) {
    on<TipLoadRequested>(_onLoad);
    on<TipPurchaseRequested>(_onPurchase);
    on<_TipServiceEvent>(_onServiceEvent);
    _sub = _service.events.listen((e) => add(_TipServiceEvent(e)));
  }

  Future<void> _onLoad(TipLoadRequested e, Emitter<TipState> emit) async {
    emit(state.copyWith(status: TipStatus.loading));
    try {
      final products = await _service.loadProducts();
      emit(
        TipState(
          status: products.isEmpty ? TipStatus.unavailable : TipStatus.ready,
          products: products,
        ),
      );
    } on Object {
      emit(state.copyWith(status: TipStatus.unavailable));
    }
  }

  Future<void> _onPurchase(
    TipPurchaseRequested e,
    Emitter<TipState> emit,
  ) async {
    emit(state.copyWith(status: TipStatus.purchasing));
    try {
      await _service.buy(e.product);
    } on Object {
      emit(state.copyWith(status: TipStatus.failed));
    }
  }

  void _onServiceEvent(_TipServiceEvent e, Emitter<TipState> emit) {
    emit(
      state.copyWith(
        status: switch (e.event) {
          TipResult.pending => TipStatus.purchasing,
          TipResult.success => TipStatus.thanks,
          TipResult.cancelled => TipStatus.ready,
          TipResult.failed => TipStatus.failed,
        },
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
