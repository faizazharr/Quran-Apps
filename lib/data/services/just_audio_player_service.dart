import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

// ignore_for_file: avoid_slow_async_io
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'audio_player_service.dart';

/// `just_audio`-backed implementation with background playback support via
/// `just_audio_background`.
///
/// Streaming strategy:
/// * If a track is already on-disk (previously played), it is loaded from the
///   local file — no network required (offline-safe).
/// * Otherwise the track is streamed directly from the HTTPS CDN via
///   [AudioSource.uri]. A background task then downloads and caches the file
///   so the *next* play is offline-capable.
///
/// We deliberately avoid LockCachingAudioSource: that class starts a local
/// HTTP proxy on 127.0.0.1 which Android 9+ and iOS ATS both block as
/// cleartext traffic, causing "Source error / CleartextNotPermitted" at
/// runtime.
class JustAudioPlayerService implements IAudioPlayerService {
  final AudioPlayer _player;
  Directory? _cacheDir;

  JustAudioPlayerService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'audio_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Returns `true` when [track] is already cached on disk.
  Future<bool> isCached(Track track) async {
    final dir = await _ensureCacheDir();
    return File(p.join(dir.path, '${track.id}.mp3')).exists();
  }

  @override
  Future<void> load(Track track) async {
    final dir = await _ensureCacheDir();
    final cacheFile = File(p.join(dir.path, '${track.id}.mp3'));

    await _player.stop();

    // Generate (or reuse cached) branded artwork for this track.
    final artUri = await _generateTrackArtwork(track);

    final mediaItem = MediaItem(
      id: track.id,
      title: track.surah.englishName,
      artist: track.artist,
      // Arabic name shows as a subtitle on supported Android versions.
      album: track.surah.name,
      artUri: artUri,
      extras: {'surahNumber': track.surah.number},
    );

    if (await cacheFile.exists()) {
      await _player.setAudioSource(
        AudioSource.file(cacheFile.path, tag: mediaItem),
      );
      return;
    }

    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(track.audioUrl), tag: mediaItem),
    );

    unawaited(_cacheInBackground(track.audioUrl, cacheFile));
  }

  // ── Branded notification artwork ──────────────────────────────────────────

  /// Generates a 512 × 512 PNG with the brand gradient, surah number, and
  /// names — giving each surah a unique Spotify-style "album art" card.
  ///
  /// The image is cached by [track.id] so subsequent loads are instant.
  /// Any rendering failure is silently swallowed; a null [artUri] simply
  /// means the OS falls back to the app launcher icon.
  Future<Uri?> _generateTrackArtwork(Track track) async {
    try {
      final dir = await _ensureCacheDir();
      final artFile = File(p.join(dir.path, 'art_${track.id}.png'));
      if (await artFile.exists()) return artFile.uri;

      const double size = 512;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        const ui.Rect.fromLTWH(0, 0, size, size),
      );

      // ── 1. Brand gradient background ──────────────────────────────────────
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, size, size),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            const ui.Offset(0, 0),
            const ui.Offset(size, size),
            const [ui.Color(0xFF0F7C5A), ui.Color(0xFF0A4D38)],
          ),
      );

      // ── 2. Decorative circles (depth / texture) ────────────────────────────
      canvas.drawCircle(
        const ui.Offset(size * 0.1, size * 0.1),
        size * 0.55,
        ui.Paint()..color = const ui.Color(0x14FFFFFF),
      );
      canvas.drawCircle(
        const ui.Offset(size * 0.92, size * 0.88),
        size * 0.38,
        ui.Paint()..color = const ui.Color(0x0AFFFFFF),
      );

      // ── 3. "Quran Player" watermark (top-left) ─────────────────────────────
      _drawParagraph(
        canvas,
        text: 'Quran Player',
        x: 28,
        y: 26,
        fontSize: 22,
        fontWeight: ui.FontWeight.w600,
        color: const ui.Color(0x80FFFFFF),
        width: size - 56,
        align: ui.TextAlign.left,
      );

      // ── 4. Surah number — large centred badge ──────────────────────────────
      _drawParagraph(
        canvas,
        text: '${track.surah.number}',
        x: 0,
        y: size * 0.22,
        fontSize: 160,
        fontWeight: ui.FontWeight.w900,
        color: const ui.Color(0xFFFFFFFF),
        width: size,
        align: ui.TextAlign.center,
      );

      // ── 5. Surah English name ──────────────────────────────────────────────
      _drawParagraph(
        canvas,
        text: track.surah.englishName,
        x: 24,
        y: size * 0.64,
        fontSize: 38,
        fontWeight: ui.FontWeight.w700,
        color: const ui.Color(0xFFFFFFFF),
        width: size - 48,
        align: ui.TextAlign.center,
      );

      // ── 6. Translation subtitle ────────────────────────────────────────────
      _drawParagraph(
        canvas,
        text: track.surah.englishNameTranslation,
        x: 24,
        y: size * 0.76,
        fontSize: 24,
        fontWeight: ui.FontWeight.w400,
        color: const ui.Color(0xB3FFFFFF),
        width: size - 48,
        align: ui.TextAlign.center,
      );

      // ── 7. Reciter name (bottom) ───────────────────────────────────────────
      _drawParagraph(
        canvas,
        text: track.artist,
        x: 24,
        y: size * 0.87,
        fontSize: 22,
        fontWeight: ui.FontWeight.w500,
        color: const ui.Color(0x99FFFFFF),
        width: size - 48,
        align: ui.TextAlign.center,
      );

      // ── Finalise and save ──────────────────────────────────────────────────
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) return null;
      await artFile.writeAsBytes(byteData.buffer.asUint8List());
      return artFile.uri;
    } catch (_) {
      return null;
    }
  }

  /// Draws a single line of styled text onto [canvas].
  void _drawParagraph(
    ui.Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required ui.FontWeight fontWeight,
    required ui.Color color,
    required double width,
    required ui.TextAlign align,
  }) {
    final style = ui.ParagraphStyle(
      textAlign: align,
      maxLines: 2,
      ellipsis: '…',
    );
    final builder = ui.ParagraphBuilder(style)
      ..pushStyle(
        ui.TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
      )
      ..addText(text);

    final para = builder.build()..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(para, ui.Offset(x, y));
    para.dispose();
  }

  // ── Audio cache helpers ───────────────────────────────────────────────────

  /// Downloads [url] to a temp file then atomically renames it to [dest].
  /// Any failure is silently swallowed — caching is best-effort.
  Future<void> _cacheInBackground(String url, File dest) async {
    final tmp = File('${dest.path}.tmp');
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) return;
        final sink = tmp.openWrite();
        try {
          await response.forEach(sink.add);
        } finally {
          await sink.close();
        }
        await tmp.rename(dest.path);
      } finally {
        client.close(force: false);
      }
    } catch (_) {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<AudioPlaybackSnapshot> get playbackStream =>
      _player.playerStateStream.map(
        (s) => AudioPlaybackSnapshot(
          playing: s.playing,
          buffering:
              s.processingState == ProcessingState.loading ||
              s.processingState == ProcessingState.buffering,
          completed: s.processingState == ProcessingState.completed,
        ),
      );

  @override
  Stream<Object> get errorStream => _player.errorStream;
}
