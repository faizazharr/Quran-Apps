import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/track.dart';
import '../../../shared/widgets/player_seek_bar.dart';
import '../../ayah/view/ayah_view.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../search/bloc/search_bloc.dart';
import '../bloc/player_bloc.dart';

/// Modern bottom player panel with animated entrance + gradient.
class PlayerPanel extends StatelessWidget {
  final bool isBottomBar;
  const PlayerPanel({super.key, this.isBottomBar = true});

  @override
  Widget build(BuildContext context) {
    // Outer panel: only react when the *track identity* changes (mount /
    // unmount). Inner widgets subscribe to the narrower slices they care
    // about so position ticks don't rebuild the whole tree.
    return BlocSelector<PlayerBloc, PlayerState, String?>(
      selector: (s) => s.track?.id,
      builder: (context, trackId) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: trackId == null
                ? const SizedBox.shrink()
                : _PanelContent(
                    key: const ValueKey('panel'),
                    isBottomBar: isBottomBar,
                  ),
          ),
        );
      },
    );
  }
}

class _PanelContent extends StatelessWidget {
  final bool isBottomBar;
  const _PanelContent({super.key, required this.isBottomBar});

  @override
  Widget build(BuildContext context) {
    Widget child = const Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          SizedBox(height: 12),
          RepaintBoundary(child: PlayerSeekBar()),
          SizedBox(height: 4),
          _Controls(),
        ],
      ),
    );

    if (isBottomBar) {
      child = SafeArea(top: false, child: child);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: isBottomBar
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    // Header only depends on the track metadata + error state, never position.
    return BlocSelector<PlayerBloc, PlayerState, _HeaderVM>(
      selector: (s) => _HeaderVM(
        track: s.track,
        isError: s.status == PlaybackStatus.error,
        errorMessage: s.errorMessage,
      ),
      builder: (context, vm) {
        final track = vm.track;
        if (track == null) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        '${track.surah.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.surah.englishName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ayah text',
                  onPressed: () {
                    final track = context.read<PlayerBloc>().state.track;
                    unawaited(
                      AyahView.show(
                        context,
                        surahNumber: track?.surah.number,
                        surah: track?.surah,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.menu_book_outlined,
                    color: Colors.white,
                  ),
                ),
                // Bookmark current position
                BlocBuilder<PlayerBloc, PlayerState>(
                  buildWhen: (p, c) => p.track?.id != c.track?.id,
                  builder: (context, playerState) {
                    final track = playerState.track;
                    if (track == null) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: 'Bookmark',
                      onPressed: () {
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
                      icon: const Icon(
                        Icons.bookmark_add_outlined,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => context.read<PlayerBloc>().add(
                    const PlayerStopRequested(),
                  ),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: vm.isError && vm.errorMessage != null
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vm.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFFD2D2),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderVM extends Equatable {
  final Track? track;
  final bool isError;
  final String? errorMessage;

  const _HeaderVM({
    required this.track,
    required this.isError,
    required this.errorMessage,
  });

  @override
  List<Object?> get props => [track?.id, isError, errorMessage];
}

class _Controls extends StatelessWidget {
  const _Controls();

  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    // Controls only need to know play/pause/loading + current position for
    // the +10s skip. Use a slim view-model so we don't rebuild on every tick.
    return BlocSelector<PlayerBloc, PlayerState, _ControlsVM>(
      selector: (s) => _ControlsVM(
        isPlaying: s.isPlaying,
        isLoading: s.isLoading,
        isCompleted: s.status == PlaybackStatus.completed,
        speed: s.speed,
      ),
      builder: (context, vm) {
        final bloc = context.read<PlayerBloc>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GhostButton(
              icon: Icons.skip_previous_rounded,
              onTap: () => _jumpToAdjacent(context, -1),
            ),
            _GhostButton(
              icon: Icons.replay_10_rounded,
              onTap: () {
                final pos = bloc.state.position;
                bloc.add(
                  PlayerSeekRequested(pos - const Duration(seconds: 10)),
                );
              },
            ),
            _PrimaryButton(
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
            _GhostButton(
              icon: Icons.forward_10_rounded,
              onTap: () {
                final pos = bloc.state.position;
                bloc.add(
                  PlayerSeekRequested(pos + const Duration(seconds: 10)),
                );
              },
            ),
            _GhostButton(
              icon: Icons.skip_next_rounded,
              onTap: () => _jumpToAdjacent(context, 1),
            ),
            _SpeedChip(
              speed: vm.speed,
              speeds: _speeds,
              onSelected: (s) => bloc.add(PlayerSpeedChanged(s)),
            ),
          ],
        );
      },
    );
  }
}

class _ControlsVM extends Equatable {
  final bool isPlaying;
  final bool isLoading;
  final bool isCompleted;
  final double speed;
  const _ControlsVM({
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
    required this.speed,
  });
  @override
  List<Object?> get props => [isPlaying, isLoading, isCompleted, speed];
}

/// Navigates to the previous (delta = -1) or next (delta = +1) surah,
/// keeping the same reciter.
void _jumpToAdjacent(BuildContext context, int delta) {
  final playerBloc = context.read<PlayerBloc>();
  final currentTrack = playerBloc.state.track;
  if (currentTrack == null) return;

  final surahs = context.read<SearchBloc>().state.surahs;
  if (surahs.isEmpty) return;

  final currentIndex = surahs.indexWhere(
    (s) => s.number == currentTrack.surah.number,
  );
  if (currentIndex == -1) return;

  final nextIndex = currentIndex + delta;
  if (nextIndex < 0 || nextIndex >= surahs.length) return;

  final nextSurah = surahs[nextIndex];
  playerBloc.add(
    PlayerTrackSelectRequested(
      Track(surah: nextSurah, edition: currentTrack.edition),
    ),
  );
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GhostButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Minimum 44×44 dp tap area (WCAG / Apple HIG / Material accessibility).
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: Icon(icon, color: Colors.white, size: 22)),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton({
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
        shadowColor: Colors.black.withValues(alpha: 0.3),
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

/// Compact pill that cycles through playback speeds on tap.
/// Long-press shows a popup menu for direct selection.
class _SpeedChip extends StatelessWidget {
  final double speed;
  final List<double> speeds;
  final ValueChanged<double> onSelected;

  const _SpeedChip({
    required this.speed,
    required this.speeds,
    required this.onSelected,
  });

  String _label(double s) =>
      s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Cycle to the next speed in the list.
        final idx = speeds.indexOf(speed);
        final next = speeds[(idx + 1) % speeds.length];
        onSelected(next);
      },
      onLongPress: () async {
        final box = context.findRenderObject()! as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final screen = MediaQuery.sizeOf(context);
        final menuHeight = speeds.length * 48.0;
        final top = (offset.dy - menuHeight).clamp(
          8.0,
          screen.height - menuHeight - 8.0,
        );

        final selected = await showMenu<double>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            top,
            offset.dx + box.size.width,
            top + menuHeight,
          ),
          items: speeds
              .map(
                (s) => PopupMenuItem<double>(
                  value: s,
                  child: Row(
                    children: [
                      if (s == speed)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(_label(s)),
                    ],
                  ),
                ),
              )
              .toList(),
        );
        if (selected != null) onSelected(selected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: speed != 1.0
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _label(speed),
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
