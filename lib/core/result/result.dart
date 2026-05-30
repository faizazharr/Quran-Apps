import '../errors/app_exception.dart';

/// A type-safe outcome of an operation that may fail.
///
/// Replaces ad-hoc try/catch + nullable returns with a single, exhaustive
/// algebraic type. Use [when] / [maybeWhen] for pattern matching.
sealed class Result<T> {
  const Result();

  /// Convenience constructors.
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(AppException error) = Failure<T>;

  /// True if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// True if this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Returns the data if success, otherwise null.
  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Failure<T>() => null,
  };

  /// Returns the error if failure, otherwise null.
  AppException? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(:final error) => error,
  };

  /// Pattern-match helper that forces both branches to be handled.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) => switch (this) {
    Success<T>(:final data) => success(data),
    Failure<T>(:final error) => failure(error),
  };

  /// Maps the success value, keeping failures unchanged.
  Result<R> map<R>(R Function(T data) mapper) => switch (this) {
    Success<T>(:final data) => Result<R>.success(mapper(data)),
    Failure<T>(:final error) => Result<R>.failure(error),
  };
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}

/// Wraps a future-returning operation, converting raw exceptions into a
/// uniform [Result]. The caller never has to write try/catch again.
Future<Result<T>> runCatching<T>(Future<T> Function() action) async {
  try {
    return Result.success(await action());
  } on AppException catch (e) {
    return Result.failure(e);
  } catch (e) {
    return Result.failure(UnknownException(e.toString()));
  }
}
