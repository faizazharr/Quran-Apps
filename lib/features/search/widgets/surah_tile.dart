import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/surah.dart';

/// Card-style list item for a single Surah.
///
/// Tapping the tile navigates to [SurahDetailPage] — it no longer triggers
/// immediate playback. The trailing indicator reflects the current player
/// state (loading / playing / idle) without acting as a button itself.
///
/// All tiles share the same intrinsic height so the parent ListView can use
/// `itemExtent` and skip per-item layout measurement.
class SurahTile extends StatelessWidget {
  final Surah surah;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const SurahTile({
    super.key,
    required this.surah,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Pre-compute colors once — avoids repeated allocation inside child
    // widgets and TweenAnimationBuilder frames.
    final activeColor = scheme.primary;
    final activeBg = scheme.primary.withValues(alpha: 0.10);
    final inactiveBg = scheme.surface;
    final activeBorder = activeColor.withValues(alpha: 0.40);
    final inactiveBorder = scheme.outlineVariant.withValues(alpha: 0.50);
    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    final primaryContainer = scheme.primaryContainer;
    final onPrimaryContainer = scheme.onPrimaryContainer;

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
                        // English name (flex) + Arabic name
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
                                  fontFamily: 'Scheherazade New',
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Translation + ayah count sub-row
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
                  const SizedBox(width: 10),
                  // Navigation / playback-state indicator — not tappable.
                  _NavIndicator(
                    isActive: isActive,
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                    activeColor: activeColor,
                    mutedColor: onSurfaceVariant.withValues(alpha: 0.60),
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

// ── Shared dot separator ──────────────────────────────────────────────────

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

// ── Number badge ─────────────────────────────────────────────────────────

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
      // FittedBox scales down 3-digit numbers (100–114) on narrow screens.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            '$number',
            style: TextStyle(
              color: active ? Colors.white : inactiveFg,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Navigation / playback-state indicator ────────────────────────────────

/// Shows the player state for this surah without being an interactive button.
///
/// • Loading (active) → spinner
/// • Playing (active) → equalizer icon
/// • Paused  (active) → play-circle outline
/// • Inactive         → chevron-right (navigation affordance)
class _NavIndicator extends StatelessWidget {
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final Color activeColor;
  final Color mutedColor;

  const _NavIndicator({
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.activeColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive && isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: activeColor),
      );
    }

    if (isActive && isPlaying) {
      return Icon(Icons.equalizer_rounded, color: activeColor, size: 24);
    }

    if (isActive) {
      // Paused on this surah — paused-circle outline.
      return Icon(
        Icons.play_circle_outline_rounded,
        color: activeColor,
        size: 24,
      );
    }

    // Inactive — chevron signals "tap to navigate".
    return Icon(Icons.chevron_right_rounded, color: mutedColor, size: 24);
  }
}
