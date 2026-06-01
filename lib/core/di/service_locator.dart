import 'package:get_it/get_it.dart';

import '../../data/datasources/ayah_data_source.dart';
import '../../data/datasources/ayah_data_source_impl.dart';
import '../../data/datasources/ayah_remote_data_source.dart';
import '../../data/datasources/ayah_remote_data_source_impl.dart';
import '../../data/datasources/bookmark_data_source.dart';
import '../../data/datasources/bookmark_data_source_impl.dart';
import '../../data/datasources/quran_local_data_source.dart';
import '../../data/datasources/quran_local_data_source_impl.dart';
import '../../data/datasources/quran_remote_data_source.dart';
import '../../data/datasources/quran_remote_data_source_impl.dart';
import '../../data/datasources/settings_data_source.dart';
import '../../data/datasources/settings_data_source_impl.dart';
import '../../data/repositories/ayah_repository.dart';
import '../../data/repositories/ayah_repository_impl.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/repositories/quran_repository_impl.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/download_service.dart';
import '../../data/services/download_service_impl.dart';
import '../../data/services/just_audio_player_service.dart';
import '../network/connectivity_service.dart';
import '../network/connectivity_service_impl.dart';
import '../network/network_client.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Wires all dependencies once at startup.
///
/// This is the single composition root for the production app. Tests should
/// register their own fakes against the same interfaces.
Future<void> configureDependencies() async {
  // --- Core infrastructure ---
  sl.registerLazySingleton<NetworkClient>(NetworkClient.new);
  sl.registerLazySingleton<DatabaseService>(DatabaseService.new);
  sl.registerLazySingleton<IConnectivityService>(ConnectivityServiceImpl.new);

  // --- Data sources ---
  sl.registerLazySingleton<IQuranRemoteDataSource>(
    () => QuranRemoteDataSourceImpl(client: sl<NetworkClient>()),
  );
  sl.registerLazySingleton<IQuranLocalDataSource>(
    () => QuranLocalDataSourceImpl(sl<DatabaseService>()),
  );
  sl.registerLazySingleton<IBookmarkDataSource>(
    () => BookmarkDataSourceImpl(sl<DatabaseService>()),
  );
  sl.registerLazySingleton<IAyahRemoteDataSource>(
    () => AyahRemoteDataSourceImpl(sl<NetworkClient>()),
  );
  sl.registerLazySingleton<IAyahDataSource>(
    () => AyahDataSourceImpl(sl<DatabaseService>()),
  );
  sl.registerLazySingleton<ISettingsDataSource>(
    () => SettingsDataSourceImpl(sl<DatabaseService>()),
  );

  // --- Services ---
  sl.registerLazySingleton<IAudioPlayerService>(JustAudioPlayerService.new);
  sl.registerLazySingleton<IDownloadService>(
    () => DownloadServiceImpl(sl<DatabaseService>()),
  );
  sl.registerLazySingleton<ICloudSyncService>(
    () => const NoOpCloudSyncService(),
  );

  // --- Repositories ---
  sl.registerLazySingleton<IQuranRepository>(
    () => QuranRepositoryImpl(
      remote: sl<IQuranRemoteDataSource>(),
      local: sl<IQuranLocalDataSource>(),
      connectivity: sl<IConnectivityService>(),
    ),
  );
  sl.registerLazySingleton<IBookmarkRepository>(
    () => BookmarkRepositoryImpl(sl<IBookmarkDataSource>()),
  );
  sl.registerLazySingleton<IAyahRepository>(
    () => AyahRepositoryImpl(
      remote: sl<IAyahRemoteDataSource>(),
      local: sl<IAyahDataSource>(),
      connectivity: sl<IConnectivityService>(),
    ),
  );
  sl.registerLazySingleton<ISettingsRepository>(
    () => SettingsRepositoryImpl(sl<ISettingsDataSource>()),
  );
}

/// Resets the locator. Useful between tests.
Future<void> resetDependencies() async => sl.reset();
