import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/core/errors/app_exception.dart';
import 'package:quran_apps/core/result/result.dart';

void main() {
  group('Result', () {
    test('Success exposes data', () {
      const r = Result<int>.success(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.dataOrNull, 42);
      expect(r.errorOrNull, isNull);
    });

    test('Failure exposes error', () {
      const r = Result<int>.failure(UnknownException('boom'));
      expect(r.isFailure, isTrue);
      expect(r.dataOrNull, isNull);
      expect(r.errorOrNull, isA<UnknownException>());
    });

    test('when() executes the matching branch', () {
      const success = Result<int>.success(1);
      const failure = Result<int>.failure(RemoteException('x'));
      expect(success.when(success: (d) => d * 2, failure: (_) => -1), 2);
      expect(failure.when(success: (d) => d * 2, failure: (_) => -1), -1);
    });

    test('map() only transforms success', () {
      const success = Result<int>.success(2);
      final mapped = success.map((d) => d + 3);
      expect(mapped.dataOrNull, 5);

      const failure = Result<int>.failure(LocalException('x'));
      final mappedFail = failure.map((d) => d + 3);
      expect(mappedFail.isFailure, isTrue);
    });

    test('runCatching wraps thrown AppExceptions', () async {
      final ok = await runCatching<int>(() async => 7);
      expect(ok.dataOrNull, 7);

      final ko = await runCatching<int>(() async {
        throw const RemoteException('nope');
      });
      expect(ko.errorOrNull, isA<RemoteException>());
    });

    test('runCatching wraps unknown errors as UnknownException', () async {
      final ko = await runCatching<int>(() async {
        throw StateError('weird');
      });
      expect(ko.errorOrNull, isA<UnknownException>());
    });
  });
}
