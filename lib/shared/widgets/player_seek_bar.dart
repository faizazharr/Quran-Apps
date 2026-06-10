import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/duration_formatter.dart';
import '../../features/player/bloc/player_bloc.dart';

/// Shared seek bar used by both [PlayerPanel] and the embedded player inside
/// [SurahDetailPage]. Always renders on a dark gradient background, so all
/// colours are white-based.
///
/// Set [compact] to `true` for the embedded variant — timestamps render at
/// 11 sp and the spacer below the slider is slightly tighter (6 dp vs 10 dp).
class PlayerSeekBar extends StatefulWidget {
  final bool compact;
  const PlayerSeekBar({super.key, this.compact = false});

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerBloc, PlayerState>(
      // Reset any in-flight drag when the track identity changes.
      listenWhen: (prev, curr) => prev.track?.id != curr.track?.id,
      listener: (ctx, s) => setState(() => _drag = null),
      child: BlocBuilder<PlayerBloc, PlayerState>(
        buildWhen: (prev, curr) =>
            prev.position != curr.position ||
            prev.duration != curr.duration ||
            prev.status != curr.status,
        builder: (context, state) {
          final totalMs = state.duration.inMilliseconds;
          final max = totalMs > 0 ? totalMs.toDouble() : 1.0;
          final live = state.position.inMilliseconds.clamp(0, totalMs);
          final value = (_drag ?? live.toDouble()).clamp(0.0, max);

          return Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.20),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: value,
                  max: max,
                  onChanged: totalMs > 0
                      ? (v) => setState(() => _drag = v)
                      : null,
                  onChangeEnd: totalMs > 0
                      ? (v) {
                          context.read<PlayerBloc>().add(
                            PlayerSeekRequested(
                              Duration(milliseconds: v.round()),
                            ),
                          );
                          setState(() => _drag = null);
                        }
                      : null,
                ),
              ),
              if (state.status == PlaybackStatus.loading)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: widget.compact ? 2 : 4,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                )
              else
                SizedBox(height: widget.compact ? 6 : 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DurationFormatter.format(
                        Duration(milliseconds: value.round()),
                      ),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: widget.compact ? 11 : 12,
                      ),
                    ),
                    Text(
                      DurationFormatter.format(state.duration),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: widget.compact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
