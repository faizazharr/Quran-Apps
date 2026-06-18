import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../features/bookmark/bloc/bookmark_bloc.dart';
import '../../features/player/bloc/player_bloc.dart';
import '../../features/search/bloc/search_bloc.dart';
import '../../features/settings/widgets/sleep_timer_dialog.dart';
import '../../features/sleep_timer/bloc/sleep_timer_bloc.dart';
import 'empty_state_view.dart';
import 'player_seek_bar.dart';

/// Persistent right-column "Now Playing" panel used in the tablet two-pane
/// layout. Shows a full-height rich player when a track is loaded, or a
/// friendly hint otherwise.
class NowPlayingPane extends StatelessWidget {
  const NowPlayingPane({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (s) => s.hasTrack,
      builder: (context, hasTrack) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: hasTrack
            ? const _FullContent(key: ValueKey('playing'))
            : const EmptyStateView(
                key: ValueKey('hint'),
                icon: Icons.headphones_rounded,
                title: 'Pick a surah to play',
                subtitle: 'Select any item from the list to start listening.',
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FullContent extends StatelessWidget {
  const _FullContent({super.key});

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return BlocListener<PlayerBloc, PlayerState>(
      listenWhen: (prev, curr) =>
          prev.status != PlaybackStatus.completed &&
          curr.status == PlaybackStatus.completed &&
          curr.repeatMode == PlayerRepeatMode.all,
      listener: (context, _) => _skipToAdjacent(context, 1),
      child: DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: BlocSelector<PlayerBloc, PlayerState, Track?>(
        selector: (s) => s.track,
        builder: (context, track) {
          if (track == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Artwork / now-playing info ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Large surah number badge
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              '${track.surah.number}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 44,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        track.surah.englishName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        track.surah.name,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Scheherazade New',
                          fontSize: 26,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.artist,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CircleBtn(
                            icon: Icons.bookmark_add_outlined,
                            tooltip: 'Bookmark',
                            onTap: () {
                              context.read<BookmarkBloc>().add(
                                BookmarkAddRequested(
                                  surahNumber: track.surah.number,
                                  editionId: track.edition.identifier,
                                  positionMs: context
                                      .read<PlayerBloc>()
                                      .state
                                      .position
                                      .inMilliseconds,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bookmarked'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          BlocSelector<SleepTimerBloc, SleepTimerState, bool>(
                            selector: (s) => s.isActive,
                            builder: (context, isActive) => _CircleBtn(
                              icon: isActive
                                  ? Icons.bedtime_rounded
                                  : Icons.bedtime_outlined,
                              tooltip: isActive
                                  ? 'Sleep timer active'
                                  : 'Sleep timer',
                              active: isActive,
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (_) => MultiBlocProvider(
                                  providers: [
                                    BlocProvider.value(
                                      value: context.read<SleepTimerBloc>(),
                                    ),
                                  ],
                                  child: const SleepTimerDialog(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          _CircleBtn(
                            icon: Icons.close_rounded,
                            tooltip: 'Stop',
                            onTap: () => context.read<PlayerBloc>().add(
                              const PlayerStopRequested(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),     // Column
                ),       // ConstrainedBox
                ),       // Center
                ),       // SingleChildScrollView
              ),         // Expanded
              // ── Controls ────────────────────────────────────────────────
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottomPad),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(child: PlayerSeekBar()),
                      SizedBox(height: 8),
                      _Controls(speeds: _speeds),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),   // DecoratedBox
    );   // BlocListener
  }
}

// ─── Controls row ─────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final List<double> speeds;
  const _Controls({required this.speeds});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, _VM>(
      selector: (s) => _VM(
        isPlaying: s.isPlaying,
        isLoading: s.isLoading,
        isCompleted: s.status == PlaybackStatus.completed,
        speed: s.speed,
        repeatMode: s.repeatMode,
      ),
      builder: (context, vm) {
        final bloc = context.read<PlayerBloc>();
        // FittedBox scales the row down on narrow panels (e.g. 300 dp right
        // column) so the 7 controls never overflow. SizedBox(width:344) sets
        // the comfortable natural width; FittedBox.scaleDown kicks in only
        // when the available width is smaller.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 344,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleBtn(
                  icon: Icons.skip_previous_rounded,
                  onTap: () => _skipToAdjacent(context, -1),
                ),
                _CircleBtn(
                  icon: Icons.replay_10_rounded,
                  onTap: () => bloc.add(
                    PlayerSeekRequested(
                      bloc.state.position - const Duration(seconds: 10),
                    ),
                  ),
                ),
                _PlayBtn(
                  icon: vm.isCompleted
                      ? Icons.replay_rounded
                      : (vm.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                  loading: vm.isLoading,
                  onTap: () {
                    if (vm.isCompleted) {
                      bloc.add(const PlayerSeekRequested(Duration.zero));
                      bloc.add(const PlayerPlayRequested());
                    } else {
                      bloc.add(
                        vm.isPlaying
                            ? const PlayerPauseRequested()
                            : const PlayerPlayRequested(),
                      );
                    }
                  },
                ),
                _CircleBtn(
                  icon: Icons.forward_10_rounded,
                  onTap: () => bloc.add(
                    PlayerSeekRequested(
                      bloc.state.position + const Duration(seconds: 10),
                    ),
                  ),
                ),
                _CircleBtn(
                  icon: Icons.skip_next_rounded,
                  onTap: () => _skipToAdjacent(context, 1),
                ),
                Tooltip(
                  message: switch (vm.repeatMode) {
                    PlayerRepeatMode.off => 'Repeat: Off',
                    PlayerRepeatMode.one => 'Repeat: On',
                    PlayerRepeatMode.all => 'Auto-play next',
                  },
                  child: _CircleBtn(
                    icon: switch (vm.repeatMode) {
                      PlayerRepeatMode.off => Icons.repeat_rounded,
                      PlayerRepeatMode.one => Icons.repeat_one_rounded,
                      PlayerRepeatMode.all => Icons.playlist_play_rounded,
                    },
                    active: vm.repeatMode != PlayerRepeatMode.off,
                    onTap: () => bloc.add(const PlayerRepeatModeChanged()),
                  ),
                ),
                _SpeedChip(
                  speed: vm.speed,
                  speeds: speeds,
                  onSelected: (s) => bloc.add(PlayerSpeedChanged(s)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VM extends Equatable {
  final bool isPlaying;
  final bool isLoading;
  final bool isCompleted;
  final double speed;
  final PlayerRepeatMode repeatMode;
  const _VM({
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
    required this.speed,
    required this.repeatMode,
  });
  @override
  List<Object?> get props =>
      [isPlaying, isLoading, isCompleted, speed, repeatMode];
}

// ─── Button primitives ────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn = SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: active ? AppColors.accent : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

class _PlayBtn extends StatelessWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _PlayBtn({
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onTap,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : Icon(icon, color: AppColors.primary, size: 30),
          ),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final List<double> speeds;
  final ValueChanged<double> onSelected;
  const _SpeedChip({
    required this.speed,
    required this.speeds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.truncateToDouble()
        ? '${speed.toInt()}x'
        : '${speed}x';
    return GestureDetector(
      onTap: () {
        final idx = speeds.indexOf(speed);
        onSelected(speeds[(idx + 1) % speeds.length]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: speed != 1.0
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: speed != 1.0 ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Navigation helper ────────────────────────────────────────────────────────

void _skipToAdjacent(BuildContext context, int delta) {
  final playerBloc = context.read<PlayerBloc>();
  final currentTrack = playerBloc.state.track;
  if (currentTrack == null) return;
  final surahs = context.read<SearchBloc>().state.surahs;
  if (surahs.isEmpty) return;
  final idx = surahs.indexWhere((s) => s.number == currentTrack.surah.number);
  if (idx == -1) return;
  final nextIdx = idx + delta;
  if (nextIdx < 0 || nextIdx >= surahs.length) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextIdx < 0
              ? 'Already at the first surah'
              : 'Already at the last surah',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  playerBloc.add(
    PlayerTrackSelectRequested(
      Track(surah: surahs[nextIdx], edition: currentTrack.edition),
    ),
  );
}
