import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'data/models/app_settings.dart';
import 'features/activity/bloc/activity_bloc.dart';
import 'features/ayah/bloc/ayah_bloc.dart';
import 'features/bookmark/bloc/bookmark_bloc.dart';
import 'features/download/bloc/download_bloc.dart';
import 'features/player/bloc/player_bloc.dart';
import 'features/quote/bloc/quote_bloc.dart';
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
          create: (_) => sl<SettingsBloc>()..add(const SettingsLoadRequested()),
        ),
        BlocProvider(
          create: (_) => sl<SearchBloc>()..add(const SearchLoadRequested()),
        ),
        BlocProvider(create: (_) => sl<PlayerBloc>()),
        BlocProvider(
          create: (_) => sl<BookmarkBloc>()..add(const BookmarkLoadRequested()),
        ),
        BlocProvider(create: (_) => sl<AyahBloc>()),
        BlocProvider(
          create: (_) => sl<DownloadBloc>()..add(const DownloadLoadRequested()),
        ),
        BlocProvider(
          create: (_) => sl<QuoteBloc>()..add(const QuoteLoadRequested()),
        ),
        BlocProvider(create: (_) => sl<SleepTimerBloc>()),
        BlocProvider(
          create: (_) => sl<ActivityBloc>()..add(const ActivityLoadRequested()),
        ),
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
            home: MultiBlocListener(
              listeners: [
                // Timed sleep: pause when countdown reaches zero.
                BlocListener<SleepTimerBloc, SleepTimerState>(
                  listenWhen: (prev, curr) =>
                      prev.status != SleepTimerStatus.expired &&
                      curr.status == SleepTimerStatus.expired,
                  listener: (context, _) => context.read<PlayerBloc>().add(
                    const PlayerPauseRequested(),
                  ),
                ),
                // End-of-surah sleep: pause + cancel timer when track completes.
                BlocListener<PlayerBloc, PlayerState>(
                  listenWhen: (prev, curr) =>
                      prev.status != PlaybackStatus.completed &&
                      curr.status == PlaybackStatus.completed,
                  listener: (context, _) {
                    final timerState = context.read<SleepTimerBloc>().state;
                    if (timerState.isActive && timerState.isEndOfSurah) {
                      context.read<SleepTimerBloc>().add(
                        const SleepTimerCancelRequested(),
                      );
                      context.read<PlayerBloc>().add(
                        const PlayerPauseRequested(),
                      );
                    }
                  },
                ),
                // Audio started playing → record "last listened" activity.
                BlocListener<PlayerBloc, PlayerState>(
                  listenWhen: (prev, curr) =>
                      prev.status != PlaybackStatus.playing &&
                      curr.status == PlaybackStatus.playing,
                  listener: (context, _) => context.read<ActivityBloc>().add(
                    ActivityListenedRecorded(DateTime.now()),
                  ),
                ),
                // Translation changed: refresh Quote of the Day so the
                // translation text matches the user's new language preference.
                BlocListener<SettingsBloc, SettingsState>(
                  listenWhen: (prev, curr) =>
                      curr.status == SettingsStatus.ready &&
                      prev.settings.translationEditionId !=
                          curr.settings.translationEditionId,
                  listener: (context, _) => context.read<QuoteBloc>().add(
                    const QuoteRefreshRequested(),
                  ),
                ),
              ],
              child: const _ConnectivityBanner(child: SearchScreen()),
            ),
          );
        },
      ),
    );
  }
}

/// Listens to network connectivity changes and shows a persistent banner at
/// the top of the scaffold when the device goes offline, and a brief "back
/// online" snack when it reconnects.
class _ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const _ConnectivityBanner({required this.child});

  @override
  State<_ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<_ConnectivityBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onChanged(List<ConnectivityResult> results) {
    final isOffline = results.every((r) => r == ConnectivityResult.none);
    if (isOffline == _offline) return;
    setState(() => _offline = isOffline);

    if (!isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Back online'),
            ],
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _offline
              ? Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No internet connection',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
