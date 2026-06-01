import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'data/models/app_settings.dart';
import 'data/repositories/ayah_repository.dart';
import 'data/repositories/bookmark_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/download_service.dart';
import 'features/ayah/bloc/ayah_bloc.dart';
import 'features/bookmark/bloc/bookmark_bloc.dart';
import 'features/download/bloc/download_bloc.dart';
import 'features/player/bloc/player_bloc.dart';
import 'features/search/bloc/search_bloc.dart';
import 'features/search/view/search_screen.dart';
import 'features/settings/bloc/settings_bloc.dart';
import 'features/sleep_timer/bloc/sleep_timer_bloc.dart';
import 'l10n/generated/app_localizations.dart';

/// Root widget. Pulls dependencies from the [GetIt] service locator
/// (configured in `main.dart`) and creates the feature BLoCs.
class QuranPlayerApp extends StatelessWidget {
  const QuranPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              SettingsBloc(sl<ISettingsRepository>())
                ..add(const SettingsLoadRequested()),
        ),
        BlocProvider(
          create: (_) =>
              SearchBloc(sl<IQuranRepository>())..add(const SearchStarted()),
        ),
        BlocProvider(create: (_) => PlayerBloc(sl<IAudioPlayerService>())),
        BlocProvider(
          create: (_) =>
              BookmarkBloc(sl<IBookmarkRepository>())
                ..add(const BookmarkLoadRequested()),
        ),
        BlocProvider(
          create: (_) =>
              AyahBloc(sl<IAyahRepository>(), sl<ISettingsRepository>()),
        ),
        BlocProvider(
          create: (_) =>
              DownloadBloc(sl<IDownloadService>())
                ..add(const DownloadLoadRequested()),
        ),
        BlocProvider(create: (_) => SleepTimerBloc()),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        buildWhen: (prev, curr) =>
            prev.settings.themeMode != curr.settings.themeMode ||
            prev.settings.localeTag != curr.settings.localeTag,
        builder: (context, settingsState) {
          final themeMode = switch (settingsState.settings.themeMode) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.system => ThemeMode.system,
          };

          final locale = settingsState.settings.localeTag != null
              ? Locale(settingsState.settings.localeTag!)
              : null;

          return MaterialApp(
            title: 'Quran Player',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.3,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: BlocListener<SleepTimerBloc, SleepTimerState>(
              listenWhen: (prev, curr) =>
                  prev.status != SleepTimerStatus.expired &&
                  curr.status == SleepTimerStatus.expired,
              listener: (context, _) =>
                  context.read<PlayerBloc>().add(const PlayerPauseRequested()),
              child: const SearchScreen(),
            ),
          );
        },
      ),
    );
  }
}
