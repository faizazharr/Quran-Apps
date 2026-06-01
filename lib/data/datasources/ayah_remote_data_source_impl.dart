import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/network_client.dart';
import '../models/ayah.dart';
import '../models/translation.dart';
import 'ayah_remote_data_source.dart';

class AyahRemoteDataSourceImpl implements IAyahRemoteDataSource {
  final NetworkClient _client;

  AyahRemoteDataSourceImpl(this._client);

  @override
  Future<List<Ayah>> fetchAyahs({
    required int surahNumber,
    required String editionId,
  }) async {
    final uri = ApiConstants.surahTextUrl(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    final json = await _client.getJson(uri);
    return _parseAyahs(json, surahNumber: surahNumber, editionId: editionId);
  }

  @override
  Future<List<Translation>> fetchTranslations({
    required int surahNumber,
    required String editionId,
  }) async {
    final uri = ApiConstants.surahTextUrl(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    final json = await _client.getJson(uri);
    return _parseTranslations(
      json,
      surahNumber: surahNumber,
      editionId: editionId,
    );
  }

  List<Ayah> _parseAyahs(
    Map<String, dynamic> json, {
    required int surahNumber,
    required String editionId,
  }) {
    try {
      final data = json['data'] as Map<String, dynamic>;
      final ayahsJson = data['ayahs'] as List<dynamic>;
      return ayahsJson
          .cast<Map<String, dynamic>>()
          .map(
            (a) => Ayah.fromJson(
              a,
              surahNumber: surahNumber,
              editionId: editionId,
            ),
          )
          .toList();
    } catch (e) {
      throw RemoteException('Failed to parse ayahs: $e');
    }
  }

  List<Translation> _parseTranslations(
    Map<String, dynamic> json, {
    required int surahNumber,
    required String editionId,
  }) {
    try {
      final data = json['data'] as Map<String, dynamic>;
      final ayahsJson = data['ayahs'] as List<dynamic>;
      return ayahsJson
          .cast<Map<String, dynamic>>()
          .map(
            (a) => Translation.fromJson(
              a,
              surahNumber: surahNumber,
              editionId: editionId,
            ),
          )
          .toList();
    } catch (e) {
      throw RemoteException('Failed to parse translations: $e');
    }
  }
}
