import 'package:flutter/material.dart';

/// Animated skeleton placeholder while data loads.
class TrackTileShimmer extends StatefulWidget {
  const TrackTileShimmer({super.key});

  @override
  State<TrackTileShimmer> createState() => _TrackTileShimmerState();
}

class _TrackTileShimmerState extends State<TrackTileShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(
      context,
    ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final color = Color.lerp(base, highlight, _ctrl.value)!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              _box(color, w: 46, h: 46, r: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(color, w: 160, h: 14, r: 6),
                    const SizedBox(height: 8),
                    _box(color, w: 100, h: 10, r: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _box(color, w: 38, h: 38, r: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _box(
    Color color, {
    required double w,
    required double h,
    required double r,
  }) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(r),
    ),
  );
}
