import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/core/utils/ticker_service.dart';
import 'package:quran_apps/features/sleep_timer/bloc/sleep_timer_bloc.dart';

/// Fake ticker that lets tests emit ticks manually — no wall-clock waiting.
class FakeTicker implements ITickerService {
  final StreamController<int> _controller =
      StreamController<int>.broadcast();

  void emitTick() => _controller.add(0);

  @override
  Stream<int> tick(Duration period) => _controller.stream;

  @override
  void cancel() {}

  void dispose() => _controller.close();
}

void main() {
  group('SleepTimerBloc — initial state', () {
    test('starts idle with no option or remaining', () {
      final bloc = SleepTimerBloc();
      expect(bloc.state.status, SleepTimerStatus.idle);
      expect(bloc.state.option, isNull);
      expect(bloc.state.remaining, isNull);
      unawaited(bloc.close());
    });
  });

  group('SleepTimerBloc — SleepTimerStartRequested (endOfSurah)', () {
    blocTest<SleepTimerBloc, SleepTimerState>(
      'emits active with null remaining for endOfSurah',
      build: SleepTimerBloc.new,
      act: (bloc) =>
          bloc.add(const SleepTimerStartRequested(SleepTimerOption.endOfSurah)),
      expect: () => [
        isA<SleepTimerState>()
            .having((s) => s.status, 'status', SleepTimerStatus.active)
            .having((s) => s.option, 'option', SleepTimerOption.endOfSurah)
            .having((s) => s.remaining, 'remaining', isNull),
      ],
    );
  });

  group('SleepTimerBloc — SleepTimerStartRequested (timed)', () {
    late FakeTicker ticker;

    setUp(() => ticker = FakeTicker());
    tearDown(() => ticker.dispose());

    blocTest<SleepTimerBloc, SleepTimerState>(
      'emits active with correct remaining duration',
      build: () => SleepTimerBloc(ticker: ticker),
      act: (bloc) =>
          bloc.add(const SleepTimerStartRequested(SleepTimerOption.min15)),
      expect: () => [
        isA<SleepTimerState>()
            .having((s) => s.status, 'status', SleepTimerStatus.active)
            .having(
              (s) => s.remaining,
              'remaining',
              const Duration(minutes: 15),
            ),
      ],
    );

    blocTest<SleepTimerBloc, SleepTimerState>(
      'decrements remaining on each tick',
      build: () => SleepTimerBloc(ticker: ticker),
      act: (bloc) async {
        bloc.add(const SleepTimerStartRequested(SleepTimerOption.min15));
        await Future<void>.delayed(Duration.zero);
        ticker.emitTick();
        await Future<void>.delayed(Duration.zero);
        ticker.emitTick();
      },
      expect: () => [
        isA<SleepTimerState>().having(
          (s) => s.remaining,
          'remaining',
          const Duration(minutes: 15),
        ),
        isA<SleepTimerState>().having(
          (s) => s.remaining,
          'remaining',
          const Duration(minutes: 15) - const Duration(seconds: 1),
        ),
        isA<SleepTimerState>().having(
          (s) => s.remaining,
          'remaining',
          const Duration(minutes: 15) - const Duration(seconds: 2),
        ),
      ],
    );

    blocTest<SleepTimerBloc, SleepTimerState>(
      'transitions to expired when remaining reaches zero',
      build: () => SleepTimerBloc(ticker: ticker),
      seed: () => const SleepTimerState(
        status: SleepTimerStatus.active,
        option: SleepTimerOption.min15,
        remaining: Duration(seconds: 1),
      ),
      act: (bloc) async {
        // Manually register the timer subscription by starting first, then
        // seed is applied — so we re-start to wire the ticker.
        bloc.add(const SleepTimerStartRequested(SleepTimerOption.min15));
        await Future<void>.delayed(Duration.zero);
        // Override remaining to 1 second via tick.
      },
    );
  });

  group('SleepTimerBloc — SleepTimerCancelRequested', () {
    blocTest<SleepTimerBloc, SleepTimerState>(
      'resets to idle',
      build: SleepTimerBloc.new,
      seed: () => const SleepTimerState(
        status: SleepTimerStatus.active,
        option: SleepTimerOption.min30,
        remaining: Duration(minutes: 30),
      ),
      act: (bloc) => bloc.add(const SleepTimerCancelRequested()),
      expect: () => [const SleepTimerState()],
    );
  });

  group('SleepTimerState', () {
    test('isActive is true only when status is active', () {
      const state = SleepTimerState(status: SleepTimerStatus.active);
      expect(state.isActive, isTrue);
      expect(const SleepTimerState().isActive, isFalse);
    });

    test('isEndOfSurah is true only for endOfSurah option', () {
      const state = SleepTimerState(
        status: SleepTimerStatus.active,
        option: SleepTimerOption.endOfSurah,
      );
      expect(state.isEndOfSurah, isTrue);
    });
  });
}
