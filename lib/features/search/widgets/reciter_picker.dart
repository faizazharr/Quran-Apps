import 'package:flutter/material.dart';

import '../../../data/models/edition.dart';

/// Pill-shaped chip displayed under the search field. Tapping it opens a
/// bottom sheet to choose another reciter.
class ReciterChip extends StatelessWidget {
  final Edition? selected;
  final VoidCallback onTap;

  const ReciterChip({super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? 'Choose a reciter'
        : (selected!.englishName.isNotEmpty
              ? selected!.englishName
              : selected!.name);

    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet listing all available reciters with a check mark on
/// the currently selected one.
///
/// Pass [surahName] to show which surah the user is choosing a reciter for.
Future<Edition?> showReciterPicker(
  BuildContext context, {
  required List<Edition> reciters,
  required Edition? selected,
  String? surahName,
}) {
  return showModalBottomSheet<Edition>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select reciter',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (surahName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        surahName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reciters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final r = reciters[i];
                    final isSelected = selected?.identifier == r.identifier;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          (r.englishName.isNotEmpty ? r.englishName : r.name)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        r.englishName.isNotEmpty ? r.englishName : r.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(r.name),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(sheetCtx).pop(r),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
