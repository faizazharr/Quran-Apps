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
    // Brand primary green — tints the notification accent on Android 8+.
    notificationColor: const Color(0xFF0F7C5A),
    // Use the app launcher icon as the small status-bar icon.
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  await configureDependencies();
  runApp(const QuranPlayerApp());
}
