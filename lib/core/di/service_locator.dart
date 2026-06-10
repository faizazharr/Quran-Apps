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
import '../../data/repositories/activity_repository.dart';
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
import '../../data/services/quote_service.dart';
import '../../features/activity/bloc/activity_bloc.dart';
import '../../features/ayah/bloc/ayah_bloc.dart';
import '../../features/bookmark/bloc/bookmark_bloc.dart';
import '../../features/download/bloc/download_bloc.dart';
import '../../features/player/audio_error_mapper.dart';
import '../../features/player/bloc/player_bloc.dart';
import '../../features/quote/bloc/quote_bloc.dart';
import '../../features/search/bloc/search_bloc.dart';
import '../../features/settings/bloc/settings_bloc.dart';
import '../../features/sleep_timer/bloc/sleep_timer_bloc.dart';
import '../network/connectivity_service.dart';
import '../network/connectivity_service_impl.dart';
import '../network/network_client.dart';
import '../utils/random_service.dart';
import '../utils/ticker_service.dart';

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
  sl.registerLazySingleton<IActivityRepository>(ActivityRepositoryImpl.new);
  sl.registerLazySingleton<IQuoteService>(
    () => QuoteServiceImpl(
      quranRepo: sl<IQuranRepository>(),
      ayahRepo: sl<IAyahRepository>(),
      settingsRepo: sl<ISettingsRepository>(),
      random: sl<IRandomService>(),
    ),
  );

  // --- Utilities ---
  sl.registerLazySingleton<IRandomService>(RandomService.new);
  sl.registerLazySingleton<ITickerService>(TickerService.new);
  sl.registerLazySingleton<AudioErrorMapper>(AudioErrorMapper.new);

  // --- BLoCs (factory — a new instance per BlocProvider.create call) ---
  sl.registerFactory<SettingsBloc>(
    () => SettingsBloc(sl<ISettingsRepository>()),
  );
  sl.registerFactory<SearchBloc>(() => SearchBloc(sl<IQuranRepository>()));
  sl.registerFactory<PlayerBloc>(
    () => PlayerBloc(
      sl<IAudioPlayerService>(),
      errorMapper: sl<AudioErrorMapper>(),
    ),
  );
  sl.registerFactory<BookmarkBloc>(
    () => BookmarkBloc(sl<IBookmarkRepository>()),
  );
  sl.registerFactory<AyahBloc>(
    () => AyahBloc(sl<IAyahRepository>(), sl<ISettingsRepository>()),
  );
  sl.registerFactory<DownloadBloc>(() => DownloadBloc(sl<IDownloadService>()));
  sl.registerFactory<QuoteBloc>(() => QuoteBloc(sl<IQuoteService>()));
  sl.registerFactory<SleepTimerBloc>(
    () => SleepTimerBloc(ticker: sl<ITickerService>()),
  );
  sl.registerFactory<ActivityBloc>(
    () => ActivityBloc(sl<IActivityRepository>()),
  );
}

/// Resets the locator. Useful between tests.
Future<void> resetDependencies() async => sl.reset();
