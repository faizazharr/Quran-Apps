import '../../core/constants/api_constants.dart';
import '../../core/network/network_client.dart';
import '../models/edition.dart';
import '../models/surah.dart';
import 'quran_remote_data_source.dart';

/// Remote source backed by [NetworkClient]. No HTTP imports here — error
/// handling and timeouts live in the client (SRP).
class QuranRemoteDataSourceImpl implements IQuranRemoteDataSource {
  final NetworkClient _client;

  QuranRemoteDataSourceImpl({required NetworkClient client}) : _client = client;

  @override
  Future<List<Surah>> fetchSurahs() async {
    final body = await _client.getJson(
      Uri.parse('${ApiConstants.baseUrl}/surah'),
    );
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => Surah.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<Edition>> fetchAudioEditions() async {
    // NOTE: we intentionally do NOT include `type=versebyverse` here. The
    // AlQuran Cloud edition catalog assigns `type=translation` to some of
    // the reciters whose full-surah audio is actually hosted on the CDN
    // (e.g. ar.abdulbasitmurattal). Filtering by `type` would exclude them.
    // The repository narrows the result down to a curated featured list.
    final body = await _client.getJson(
      Uri.parse('${ApiConstants.baseUrl}/edition?format=audio'),
    );
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => Edition.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
