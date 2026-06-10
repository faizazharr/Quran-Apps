import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/activity_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the user's last-read and last-listened timestamps in a pair of small
/// pill-shaped tiles. Returns [SizedBox.shrink] when neither timestamp has
/// been recorded yet.
class LastActivityCard extends StatelessWidget {
  const LastActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ActivityBloc, ActivityState, (DateTime?, DateTime?)>(
      selector: (s) => (s.lastReadAt, s.lastListenedAt),
      builder: (context, data) {
        final (lastRead, lastListened) = data;
        if (lastRead == null && lastListened == null) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section label ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Your Activity',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Tile row ───────────────────────────────────────────────────
              Row(
                children: [
                  if (lastRead != null)
                    Expanded(
                      child: _ActivityTile(
                        icon: Icons.menu_book_rounded,
                        label: 'Last read',
                        time: lastRead,
                      ),
                    ),
                  if (lastRead != null && lastListened != null)
                    const SizedBox(width: 8),
                  if (lastListened != null)
                    Expanded(
                      child: _ActivityTile(
                        icon: Icons.headphones_rounded,
                        label: 'Last listened',
                        time: lastListened,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime time;

  const _ActivityTile({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const brandGreen = Color(0xFF0F7C5A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: brandGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: brandGreen),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(time),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time formatting
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a human-friendly relative time string for [time].
///
/// Examples: "Just now", "5 min ago", "Today 14:30", "Yesterday 09:15",
/// "3 days ago", "12/3/2025".
String _relativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';

  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');

  // Same calendar day
  final today = DateTime(now.year, now.month, now.day);
  final timeDay = DateTime(time.year, time.month, time.day);
  if (timeDay == today) return 'Today $hh:$mm';

  // Yesterday
  final yesterday = today.subtract(const Duration(days: 1));
  if (timeDay == yesterday) return 'Yesterday $hh:$mm';

  // Within 6 days
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  // Older: show date
  return '${time.day}/${time.month}/${time.year}';
}
