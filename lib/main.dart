import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise background audio service before any AudioPlayer is created.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.quranplayer.audio',
    androidNotificationChannelName: 'Quran Player',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  await configureDependencies();
  runApp(const QuranPlayerApp());
}
