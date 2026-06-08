/// Maps raw audio-engine exceptions to user-readable messages.
///
/// Rules are checked in order; the first match wins. If no rule matches,
/// a generic fallback message is returned.
class AudioErrorMapper {
  static final _rules = <_ErrorRule>[
    _ErrorRule(
      RegExp(r'403|forbidden', caseSensitive: false),
      'This reciter is not available for full-surah streaming.',
    ),
    _ErrorRule(
      RegExp(r'404', caseSensitive: false),
      'Audio file not found for this surah.',
    ),
    _ErrorRule(
      RegExp(r'socket|network', caseSensitive: false),
      'Network error while loading audio. Check your connection.',
    ),
  ];

  String describe(Object error) {
    final raw = error.toString();
    for (final rule in _rules) {
      if (rule.matches(raw)) return rule.message;
    }
    return 'Unable to load audio.';
  }
}

class _ErrorRule {
  final RegExp pattern;
  final String message;
  const _ErrorRule(this.pattern, this.message);
  bool matches(String raw) => pattern.hasMatch(raw);
}
