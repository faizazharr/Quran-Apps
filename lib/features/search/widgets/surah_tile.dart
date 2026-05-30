import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/surah.dart';

/// Card-style list item for a single Surah. The reciter is selected globally
/// at the header, so the tile only shows surah metadata.
class SurahTile extends StatelessWidget {
  final Surah surah;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  /// Name of the currently selected reciter — always shown so the user can
  /// confirm which reciter will play when they tap the tile.
  final String reciterName;

  const SurahTile({
    super.key,
    required this.surah,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    required this.reciterName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final activeColor = scheme.primary;
    final activeBg = scheme.primary.withValues(alpha: 0.10);
    final inactiveBg = scheme.surface;
    final activeBorder = activeColor.withValues(alpha: 0.4);
    final inactiveBorder = scheme.outlineVariant.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: isActive ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        builder: (context, t, child) {
          final bg = Color.lerp(inactiveBg, activeBg, t)!;
          final border = Color.lerp(inactiveBorder, activeBorder, t)!;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _NumberBadge(number: surah.number, active: isActive),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                surah.englishName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? activeColor
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              surah.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFamily: 'serif',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                surah.englishNameTranslation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Dot(),
                            const SizedBox(width: 8),
                            Text(
                              '${surah.numberOfAyahs} ayah',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (reciterName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.record_voice_over_rounded,
                                size: 11,
                                color: isActive
                                    ? activeColor
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  reciterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: isActive
                                        ? activeColor
                                        : scheme.onSurfaceVariant,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TrailingControl(
                    isActive: isActive,
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  final bool active;
  const _NumberBadge({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: active ? AppColors.brandGradient : null,
        color: active ? null : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: active
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrailingControl extends StatelessWidget {
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  const _TrailingControl({
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isActive && isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isActive && isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: isActive ? scheme.onPrimary : scheme.onSurface,
        size: 22,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        shape: BoxShape.circle,
      ),
    );
  }
}
