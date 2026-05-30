import '../models/edition.dart';
import '../models/surah.dart';

/// Contract for the remote AlQuran Cloud data source.
///
/// Defined as an interface (Dependency Inversion) so the repository can be
/// tested with a fake without spinning up an HTTP server.
abstract class IQuranRemoteDataSource {
  Future<List<Surah>> fetchSurahs();
  Future<List<Edition>> fetchAudioEditions();
}
