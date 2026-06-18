import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/edition.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/track.dart';
import '../../player/bloc/player_bloc.dart';
import '../../search/bloc/search_bloc.dart';
import '../../surah/view/surah_detail_page.dart';
import '../bloc/bookmark_bloc.dart';

/// Standalone Bookmarks tab — lists all user-created bookmarks and the
/// last-played position. Tapping a bookmark navigates to the surah and
/// restores the saved position.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Gradient header matching other screens.
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 22),
            child: const Row(
              children: [
                Icon(Icons.bookmark_rounded, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookmarks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Your saved positions',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bookmark list.
          Expanded(
            child: BlocBuilder<BookmarkBloc, BookmarkState>(
              builder: (context, state) {
                if (state.status == BookmarkStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.bookmarks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_outline_rounded,
                            size: 64,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'While playing a surah, tap the bookmark icon\nto save your position.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Breakpoints.contentMaxWidth,
                    ),
                    child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.bookmarks.length,
                  itemBuilder: (context, i) {
                    final b = state.bookmarks[i];
                    final searchState = context.read<SearchBloc>().state;
                    final surahName =
                        searchState.surahs
                            .where((s) => s.number == b.surahNumber)
                            .map((s) => s.englishName)
                            .firstOrNull ??
                        'Surah ${b.surahNumber}';
                    final reciterName =
                        searchState.reciters
                            .where((e) => e.identifier == b.editionId)
                            .map((e) => e.englishName)
                            .firstOrNull ??
                        b.editionId;
                    final position = DurationFormatter.format(
                      Duration(milliseconds: b.positionMs),
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _onTap(
                            context,
                            b.surahNumber,
                            b.editionId,
                            b.positionMs,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Surah number badge
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.brandGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${b.surahNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        surahName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$reciterName · $position',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: scheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text('Delete bookmark?'),
                                        content: const Text(
                                          'This bookmark will be permanently removed.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && context.mounted) {
                                      context.read<BookmarkBloc>().add(
                                        BookmarkDeleteRequested(b.id!),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),   // ListView.builder
                  ), // ConstrainedBox
                );   // Center — ends the return statement
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(
    BuildContext context,
    int surahNumber,
    String editionId,
    int positionMs,
  ) {
    final searchState = context.read<SearchBloc>().state;
    final surah = searchState.surahs.cast<Surah?>().firstWhere(
      (s) => s?.number == surahNumber,
      orElse: () => null,
    );
    if (surah == null) return;

    final reciter = searchState.reciters.cast<Edition?>().firstWhere(
      (e) => e?.identifier == editionId,
      orElse: () => null,
    );

    if (reciter != null) {
      context.read<PlayerBloc>().add(
        PlayerTrackSelectRequested(Track(surah: surah, edition: reciter)),
      );
      if (positionMs > 0) {
        context.read<PlayerBloc>().add(
          PlayerSeekRequested(Duration(milliseconds: positionMs)),
        );
      }
    }

    unawaited(SurahDetailPage.show(context, surah));
  }
}
