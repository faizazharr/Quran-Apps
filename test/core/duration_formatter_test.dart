import 'package:flutter_test/flutter_test.dart';
import 'package:quran_apps/core/utils/duration_formatter.dart';

void main() {
  group('DurationFormatter.format', () {
    test('formats zero as 00:00', () {
      expect(DurationFormatter.format(Duration.zero), '00:00');
    });

    test('formats seconds with leading zero', () {
      expect(DurationFormatter.format(const Duration(seconds: 5)), '00:05');
    });

    test('formats minutes and seconds', () {
      expect(
        DurationFormatter.format(const Duration(minutes: 3, seconds: 9)),
        '03:09',
      );
    });

    test('formats hours, minutes and seconds', () {
      expect(
        DurationFormatter.format(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '1:02:03',
      );
    });

    test('clamps negative durations to zero', () {
      expect(DurationFormatter.format(const Duration(seconds: -10)), '00:00');
    });
  });
}
