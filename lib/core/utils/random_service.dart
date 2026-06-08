import 'dart:math';

/// Abstraction over [Random] so callers can be tested deterministically.
abstract class IRandomService {
  /// Returns a non-negative random integer in [0, max).
  int nextInt(int max);
}

class RandomService implements IRandomService {
  final Random _random;

  RandomService({Random? random}) : _random = random ?? Random();

  @override
  int nextInt(int max) => _random.nextInt(max);
}
