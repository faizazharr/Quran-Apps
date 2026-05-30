import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/quran_repository.dart';
import 'data/services/audio_player_service.dart';
import 'features/player/bloc/player_bloc.dart';
import 'features/search/bloc/search_bloc.dart';
import 'features/search/view/search_screen.dart';

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
              SearchBloc(sl<IQuranRepository>())..add(const SearchStarted()),
        ),
        BlocProvider(create: (_) => PlayerBloc(sl<IAudioPlayerService>())),
      ],
      child: MaterialApp(
        title: 'Quran Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Clamp the platform text scaler so accessibility settings can grow
        // text up to 130% without breaking single-line layouts (badges,
        // controls). Honours user preference within a sensible range.
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
        home: const SearchScreen(),
      ),
    );
  }
}
