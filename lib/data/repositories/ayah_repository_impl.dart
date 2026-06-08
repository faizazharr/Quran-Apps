import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/result/result.dart';
import '../datasources/ayah_data_source.dart';
import '../datasources/ayah_remote_data_source.dart';
import '../models/ayah.dart';
import '../models/translation.dart';
import 'ayah_repository.dart';
import 'cache_first_mixin.dart';

/// Cache-first repository for ayahs and translations.
///
/// Behavior matches [QuranRepositoryImpl]:
///   1. Cache hit → return immediately + trigger silent background refresh.
///   2. Cache miss + online → fetch, cache, return.
///   3. Cache miss + offline → [OfflineException].
class AyahRepositoryImpl with CacheFirstMixin implements IAyahRepository {
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

  // ---------- public API ----------

  @override
  Future<Result<List<Ayah>>> getAyahs({
    required int surahNumber,
    required String editionId,
    bool forceRefresh = false,
  }) => runCatching(
    () => _loadAyahs(
      surahNumber: surahNumber,
      editionId: editionId,
      forceRefresh: forceRefresh,
    ),
  );

  @override
  Future<Result<List<Translation>>> getTranslations({
    required int surahNumber,
    required String editionId,
    bool forceRefresh = false,
  }) => runCatching(
    () => _loadTranslations(
      surahNumber: surahNumber,
      editionId: editionId,
      forceRefresh: forceRefresh,
    ),
  );

  // ---------- internals ----------

  Future<List<Ayah>> _loadAyahs({
    required int surahNumber,
    required String editionId,
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cached = await _local.getCachedAyahs(
        surahNumber: surahNumber,
        editionId: editionId,
      );
      if (cached.isNotEmpty) {
        // Return cache immediately; refresh silently in background.
        if (await _connectivity.isConnected()) {
          unawaited(
            _refreshAyahsSilently(
              surahNumber: surahNumber,
              editionId: editionId,
            ),
          );
        }
        return cached;
      }
    }

    final isOnline = await _connectivity.isConnected();
    if (!isOnline) throw const OfflineException();

    final ayahs = await _remote.fetchAyahs(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    await _local.cacheAyahs(ayahs);
    return ayahs;
  }

  Future<List<Translation>> _loadTranslations({
    required int surahNumber,
    required String editionId,
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cached = await _local.getCachedTranslations(
        surahNumber: surahNumber,
        editionId: editionId,
      );
      if (cached.isNotEmpty) {
        if (await _connectivity.isConnected()) {
          unawaited(
            _refreshTranslationsSilently(
              surahNumber: surahNumber,
              editionId: editionId,
            ),
          );
        }
        return cached;
      }
    }

    final isOnline = await _connectivity.isConnected();
    if (!isOnline) throw const OfflineException();

    final translations = await _remote.fetchTranslations(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    await _local.cacheTranslations(translations);
    return translations;
  }

  Future<void> _refreshAyahsSilently({
    required int surahNumber,
    required String editionId,
  }) => refreshSilently(() async {
    final ayahs = await _remote.fetchAyahs(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    await _local.cacheAyahs(ayahs);
  });

  Future<void> _refreshTranslationsSilently({
    required int surahNumber,
    required String editionId,
  }) => refreshSilently(() async {
    final translations = await _remote.fetchTranslations(
      surahNumber: surahNumber,
      editionId: editionId,
    );
    await _local.cacheTranslations(translations);
  });
}
