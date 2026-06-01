import '../../core/errors/app_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/result/result.dart';
import '../datasources/ayah_data_source.dart';
import '../datasources/ayah_remote_data_source.dart';
import '../models/ayah.dart';
import '../models/translation.dart';
import 'ayah_repository.dart';

class AyahRepositoryImpl implements IAyahRepository {
  final IAyahRemoteDataSource _remote;
  final IAyahDataSource _local;
  final IConnectivityService _connectivity;

  AyahRepositoryImpl({
    required IAyahRemoteDataSource remote,
    required IAyahDataSource local,
    required IConnectivityService connectivity,
  }) : _remote = remote,
       _local = local,
       _connectivity = connectivity;

  @override
  Future<Result<List<Ayah>>> getAyahs({
    required int surahNumber,
    required String editionId,
    bool forceRefresh = false,
  }) => runCatching(() async {
    if (!forceRefresh) {
      final cached = await _local.getCachedAyahs(
        surahNumber: surahNumber,
        editionId: editionId,
      );
      if (cached.isNotEmpty) return cached;
    }

    final isOnline = await _connectivity.isConnected();
    if (!isOnline) {
      final cached = await _local.getCachedAyahs(
        surahNumber: surahNumber,
        editionId: editionId,
      );
      if (cached.isNotEmpty) return cached;
      throw const OfflineException('No internet connection');
    }

    final ayahs = await _remote.fetchAyahs(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    await _local.cacheAyahs(ayahs);
    return ayahs;
  });

  @override
  Future<Result<List<Translation>>> getTranslations({
    required int surahNumber,
    required String editionId,
    bool forceRefresh = false,
  }) => runCatching(() async {
    if (!forceRefresh) {
      final cached = await _local.getCachedTranslations(
        surahNumber: surahNumber,
        editionId: editionId,
      );
      if (cached.isNotEmpty) return cached;
    }

    final isOnline = await _connectivity.isConnected();
    if (!isOnline) {
      final cached = await _local.getCachedTranslations(
        surahNumber: surahNumber,
        editionId: editionId,
      );
      if (cached.isNotEmpty) return cached;
      throw const OfflineException('No internet connection');
    }

    final translations = await _remote.fetchTranslations(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    await _local.cacheTranslations(translations);
    return translations;
  });
}
