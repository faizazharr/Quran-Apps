/// Abstraction over `dart:async` timers so BLoCs that need periodic ticks
/// can be unit-tested without waiting for real wall-clock time.
abstract class ITickerService {
  /// Returns a stream that emits integers (0, 1, 2, …) on each [period].
  Stream<int> tick(Duration period);

  /// Cancels the current tick stream.
  void cancel();
}

/// Production implementation backed by [Stream.periodic].
class TickerService implements ITickerService {
  Stream<int>? _stream;

  @override
  Stream<int> tick(Duration period) {
    _stream = Stream.periodic(period, (i) => i);
    return _stream!;
  }

  @override
  void cancel() {
    _stream = null;
  }
}
