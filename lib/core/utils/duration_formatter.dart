/// Utility for formatting [Duration] values into mm:ss or hh:mm:ss strings.
class DurationFormatter {
  DurationFormatter._();

  /// Returns a zero-padded human-readable representation of [duration].
  ///
  /// Examples:
  ///   `Duration(seconds: 5)`        -> `"00:05"`
  ///   `Duration(minutes: 3, seconds: 9)` -> `"03:09"`
  ///   `Duration(hours: 1, minutes: 2, seconds: 3)` -> `"1:02:03"`
  static String format(Duration duration) {
    final d = duration.isNegative ? Duration.zero : duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    String two(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${two(minutes)}:${two(seconds)}';
    }
    return '${two(minutes)}:${two(seconds)}';
  }
}
