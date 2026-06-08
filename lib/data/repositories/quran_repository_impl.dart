import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/result/result.dart';
import '../../core/utils/search_normalizer.dart';
import '../datasources/quran_local_data_source.dart';
import '../datasources/quran_remote_data_source.dart';
import '../models/edition.dart';
import '../models/surah.dart';
import '../models/track.dart';
import 'cache_first_mixin.dart';
import 'quran_repository.dart';

/// Pure value object returned by [QuranRepositoryImpl._composeTracks].
/// Eliminates side effects from the composition function.
class _ComposedData {
  final List<Surah> surahs;
  final List<Edition> reciters;
  final List<Track> tracks;

  const _ComposedData({
    required this.surahs,
    required this.reciters,
    required this.tracks,
  });
}

/// Default cache-first repository.
///
/// Behavior:
///   1. If cache is populated → return immediately and refresh in background.
///   2. If cache is empty + online → fetch, cache, return.
///   3. If cache is empty + offline → [OfflineException].
class QuranRepositoryImpl with CacheFirstMixin implements IQuranRepository {
  final IQuranRemoteDataSource _remote;
  final IQuranLocalDataSource _local;
  final IConnectivityService _connectivity;

  List<Track>? _tracksMemoryCache;
  List<Surah>? _surahsMemoryCache;
  List<Edition>? _recitersMemoryCache;

  /// Reciters verified (May 2026) to have full-surah MP3s on
  /// `cdn.islamic.network/quran/audio-surah/128/{id}/{surah}.mp3`. Every
  /// other edition returned by the AlQuran Cloud `/edition?format=audio`
  /// endpoint returns HTTP 403 from the surah-audio CDN.
  static const Set<String> _featuredReciters = {
    'ar.alafasy',
    'ar.abdulbasitmurattal',
    'ar.abdullahbasfar',
  };

  QuranRepositoryImpl({
    required IQuranRemoteDataSource remote,
    required IQuranLocalDataSource local,
    required IConnectivityService connectivity,
  }) : _remote = remote,
       _local = local,
       _connectivity = connectivity;

  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) {
    return runCatching(() => _loadTracks(forceRefresh: forceRefresh));
  }

  @override
  Future<Result<List<Surah>>> getSurahs({bool forceRefresh = false}) {
    return runCatching(() async {
      await _loadTracks(forceRefresh: forceRefresh);
      return _surahsMemoryCache ?? const <Surah>[];
    });
  }

  @override
  Future<Result<List<Edition>>> getReciters() {
    return runCatching(() async {
      await _loadTracks(forceRefresh: false);
      return _recitersMemoryCache ?? const <Edition>[];
    });
  }

  @override
  Future<Result<List<Track>>> search(String query) {
    return runCatching(() async {
      final tracks = await _loadTracks(forceRefresh: false);
      final q = query.trim();
      if (q.isEmpty) return tracks;
      return tracks.where((t) => t.matches(q)).toList();
    });
  }

  @override
  Future<Result<List<Surah>>> searchSurahs(String query) {
    return runCatching(() async {
      await _loadTracks(forceRefresh: false);
      final surahs = _surahsMemoryCache ?? const <Surah>[];
      final q = query.trim();
      if (q.isEmpty) return surahs;
      final asNumber = int.tryParse(q);
      return surahs.where((s) {
        if (asNumber != null && s.number == asNumber) return true;
        return fuzzyContains(s.englishName, q) ||
            fuzzyContains(s.englishNameTranslation, q) ||
            fuzzyContains(s.name, q);
      }).toList();
    });
  }

  // ---------- internals ----------

  Future<List<Track>> _loadTracks({required bool forceRefresh}) async {
    if (!forceRefresh && _tracksMemoryCache != null) {
      return _tracksMemoryCache!;
    }

    final hasCache = await _local.hasCachedData();
    final isOnline = await _connectivity.isConnected();

    if (hasCache && !forceRefresh) {
      final tracks = await _buildFromLocal();
      _tracksMemoryCache = tracks;
      if (isOnline) {
        // Best-effort background refresh.
        unawaited(_refreshFromRemoteSilently());
      }
      return tracks;
    }

    if (!isOnline) {
      throw const OfflineException();
    }

    await _refreshFromRemote();
    final tracks = await _buildFromLocal();
    if (tracks.isEmpty) {
      throw const NoDataException('Remote returned no usable data.');
    }
    _tracksMemoryCache = tracks;
    return tracks;
  }

  Future<List<Track>> _buildFromLocal() async {
    final surahs = await _local.getSurahs();
    final editions = await _local.getEditions();
    final composed = _composeTracks(surahs, editions);
    _surahsMemoryCache = composed.surahs;
    _recitersMemoryCache = composed.reciters;
    return composed.tracks;
  }

  Future<void> _refreshFromRemote() async {
    final surahs = await _remote.fetchSurahs();
    final editions = await _remote.fetchAudioEditions();
    await _local.cacheSurahs(surahs);
    await _local.cacheEditions(editions);
    final composed = _composeTracks(surahs, editions);
    _surahsMemoryCache = composed.surahs;
    _recitersMemoryCache = composed.reciters;
    _tracksMemoryCache = composed.tracks;
  }

  Future<void> _refreshFromRemoteSilently() =>
      refreshSilently(_refreshFromRemote);

  /// Pure composition — no side effects. Callers assign the returned caches.
  _ComposedData _composeTracks(List<Surah> surahs, List<Edition> editions) {
    final filtered = editions
        .where((e) => _featuredReciters.contains(e.identifier))
        .toList();
    final reciters = filtered.isNotEmpty ? filtered : editions.take(4).toList();

    return _ComposedData(
      surahs: List.unmodifiable(surahs),
      reciters: List.unmodifiable(reciters),
      tracks: [
        for (final s in surahs)
          for (final e in reciters) Track(surah: s, edition: e),
      ],
    );
  }
}
