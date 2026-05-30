import 'package:get_it/get_it.dart';

import '../../data/datasources/quran_local_data_source.dart';
import '../../data/datasources/quran_local_data_source_impl.dart';
import '../../data/datasources/quran_remote_data_source.dart';
import '../../data/datasources/quran_remote_data_source_impl.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/repositories/quran_repository_impl.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/database_service.dart';
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

  // --- Services ---
  sl.registerLazySingleton<IAudioPlayerService>(JustAudioPlayerService.new);

  // --- Repositories ---
  sl.registerLazySingleton<IQuranRepository>(
    () => QuranRepositoryImpl(
      remote: sl<IQuranRemoteDataSource>(),
      local: sl<IQuranLocalDataSource>(),
      connectivity: sl<IConnectivityService>(),
    ),
  );
}

/// Resets the locator. Useful between tests.
Future<void> resetDependencies() async => sl.reset();
