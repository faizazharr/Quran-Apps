import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/track.dart';
import '../../ayah/bloc/ayah_bloc.dart';
import '../../ayah/view/ayah_view.dart';
import '../bloc/player_bloc.dart';

/// Modern bottom player panel with animated entrance + gradient.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

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
                : const _PanelContent(key: ValueKey('panel')),
          ),
        );
      },
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              SizedBox(height: 12),
              _SeekBar(),
              SizedBox(height: 4),
              _Controls(),
            ],
          ),
        ),
      ),
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
        return Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                '${track.surah.number}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (vm.isError && vm.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      vm.errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFD2D2),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ayah text',
              onPressed: () {
                final ayahBloc = context.read<AyahBloc>();
                final track = context.read<PlayerBloc>().state.track;
                if (track != null) {
                  ayahBloc.add(AyahLoadRequested(track.surah.number));
                }
                AyahView.show(context);
              },
              icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () =>
                  context.read<PlayerBloc>().add(const PlayerStopRequested()),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
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

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    // Seek bar is the *only* thing that needs position ticks.
    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.position != curr.position || prev.duration != curr.duration,
      builder: (context, state) {
        final totalMs = state.duration.inMilliseconds;
        final max = totalMs > 0 ? totalMs.toDouble() : 1.0;
        final liveMs = state.position.inMilliseconds.clamp(0, totalMs);
        final value = (_dragValue ?? liveMs.toDouble()).clamp(0.0, max);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.2),
                trackHeight: 3,
              ),
              child: Slider(
                value: value,
                max: max,
                onChanged: totalMs > 0
                    ? (v) => setState(() => _dragValue = v)
                    : null,
                onChangeEnd: totalMs > 0
                    ? (v) {
                        context.read<PlayerBloc>().add(
                          PlayerSeekRequested(
                            Duration(milliseconds: v.round()),
                          ),
                        );
                        setState(() => _dragValue = null);
                      }
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DurationFormatter.format(
                      Duration(milliseconds: value.round()),
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    DurationFormatter.format(state.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
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
        speed: s.speed,
      ),
      builder: (context, vm) {
        final bloc = context.read<PlayerBloc>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GhostButton(
              icon: Icons.replay_rounded,
              onTap: () => bloc.add(const PlayerSeekRequested(Duration.zero)),
            ),
            const SizedBox(width: 16),
            _PrimaryButton(
              icon: vm.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              loading: vm.isLoading,
              onTap: () => bloc.add(
                vm.isPlaying
                    ? const PlayerPauseRequested()
                    : const PlayerPlayRequested(),
              ),
            ),
            const SizedBox(width: 16),
            _GhostButton(
              icon: Icons.forward_10_rounded,
              onTap: () {
                final pos = bloc.state.position;
                bloc.add(
                  PlayerSeekRequested(pos + const Duration(seconds: 10)),
                );
              },
            ),
            const SizedBox(width: 16),
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
  final double speed;
  const _ControlsVM({
    required this.isPlaying,
    required this.isLoading,
    required this.speed,
  });
  @override
  List<Object?> get props => [isPlaying, isLoading, speed];
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GhostButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
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
        final selected = await showMenu<double>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy - speeds.length * 48.0,
            offset.dx + box.size.width,
            offset.dy,
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
