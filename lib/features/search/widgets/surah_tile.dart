import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/surah.dart';

/// Card-style list item for a single Surah.
/// All tiles have a fixed layout height of 76 px so the parent ListView can
/// use [itemExtent] and skip per-item layout measurement entirely.
class SurahTile extends StatelessWidget {
  final Surah surah;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onReadTap;

  const SurahTile({
    super.key,
    required this.surah,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.onLongPress,
    required this.onReadTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Pre-compute all colors once — avoids repeated Color object allocation
    // inside child widgets and TweenAnimationBuilder frames.
    final activeColor = scheme.primary;
    final activeBg = scheme.primary.withValues(alpha: 0.10);
    final inactiveBg = scheme.surface;
    final activeBorder = activeColor.withValues(alpha: 0.4);
    final inactiveBorder = scheme.outlineVariant.withValues(alpha: 0.5);
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final primaryContainer = scheme.primaryContainer;
    final onPrimaryContainer = scheme.onPrimaryContainer;
    final surfaceContainerHighest = scheme.surfaceContainerHighest;
    final secondaryContainer = scheme.secondaryContainer;
    final onSecondaryContainer = scheme.onSecondaryContainer;
    final onPrimary = scheme.onPrimary;

    // AnimatedContainer handles the active↔inactive color transition without
    // a separate AnimationController/Ticker per tile.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? activeBorder : inactiveBorder),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NumberBadge(
                    number: surah.number,
                    active: isActive,
                    activeGradient: AppColors.brandGradient,
                    inactiveBg: primaryContainer,
                    inactiveFg: onPrimaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title row — English name (flex) + Arabic name
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                surah.englishName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  height: 1.2,
                                  color: isActive ? activeColor : onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 0,
                              child: Text(
                                surah.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontFamily: 'serif',
                                  fontSize: 15,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Subtitle row — translation + ayah count
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                surah.englishNameTranslation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _dot,
                            const SizedBox(width: 6),
                            Text(
                              '${surah.numberOfAyahs} ayah',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ReadButton(
                    onTap: onReadTap,
                    isActive: isActive,
                    bgColor: isActive
                        ? secondaryContainer
                        : surfaceContainerHighest,
                    fgColor: isActive ? onSecondaryContainer : onSurface,
                  ),
                  const SizedBox(width: 6),
                  _TrailingControl(
                    isActive: isActive,
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                    activeBg: activeColor,
                    inactiveBg: surfaceContainerHighest,
                    activeFg: onPrimary,
                    inactiveFg: onSurface,
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

// Shared const dot — allocated once, never rebuilt.
const Widget _dot = _Dot();

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 3,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x80888888),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  final bool active;
  final Gradient activeGradient;
  final Color inactiveBg;
  final Color inactiveFg;

  const _NumberBadge({
    required this.number,
    required this.active,
    required this.activeGradient,
    required this.inactiveBg,
    required this.inactiveFg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: active ? activeGradient : null,
        color: active ? null : inactiveBg,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: active ? Colors.white : inactiveFg,
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
  final Color activeBg;
  final Color inactiveBg;
  final Color activeFg;
  final Color inactiveFg;

  const _TrailingControl({
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.activeBg,
    required this.inactiveBg,
    required this.activeFg,
    required this.inactiveFg,
  });

  @override
  Widget build(BuildContext context) {
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
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isActive && isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: isActive ? activeFg : inactiveFg,
        size: 22,
      ),
    );
  }
}

class _ReadButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;
  final Color bgColor;
  final Color fgColor;

  const _ReadButton({
    required this.onTap,
    required this.isActive,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.menu_book_rounded, color: fgColor, size: 20),
      ),
    );
  }
}
