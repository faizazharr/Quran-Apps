import 'package:equatable/equatable.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/search_normalizer.dart';
import 'edition.dart';
import 'surah.dart';

/// A playable item shown in the search list and player.
///
/// In this app a "song" is the combination of a Surah (title) and an
/// audio Edition / reciter (artist).
class Track extends Equatable {
  final Surah surah;
  final Edition edition;

  const Track({required this.surah, required this.edition});

  /// Unique identifier combining surah number and reciter.
  String get id => '${surah.number}-${edition.identifier}';

  /// Title shown in the UI (Surah English name + Arabic name).
  String get title => '${surah.englishName} • ${surah.name}';

  /// Artist (reciter) shown in the UI.
  String get artist =>
      edition.englishName.isNotEmpty ? edition.englishName : edition.name;

  /// Full streaming URL for this track.
  String get audioUrl => ApiConstants.surahAudioUrl(
    editionIdentifier: edition.identifier,
    surahNumber: surah.number,
  );

  /// Returns true if [query] fuzzy-matches title, artist, translation, or
  /// surah number. "al fatihah" matches "Al-Faatiha", etc.
  bool matches(String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    if (surah.number.toString() == q) return true;
    return fuzzyContains(surah.englishName, q) ||
        fuzzyContains(surah.englishNameTranslation, q) ||
        fuzzyContains(surah.name, q) ||
        fuzzyContains(artist, q);
  }

  @override
  List<Object?> get props => [surah, edition];
}
