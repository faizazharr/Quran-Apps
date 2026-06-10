import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive.dart';
import '../../../data/models/edition.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/track.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../activity/widgets/last_activity_card.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../player/bloc/player_bloc.dart';
import '../../player/view/player_panel.dart';
import '../../quote/view/quote_card.dart';
import '../../settings/view/settings_screen.dart';
import '../../sleep_timer/bloc/sleep_timer_bloc.dart';
import '../../surah/view/surah_detail_page.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_header.dart';
import '../widgets/surah_tile.dart';
import '../widgets/track_tile_shimmer.dart';

/// Main screen — adapts between:
///   • compact / portrait : header + list + bottom player panel
///   • two-pane (landscape phone, tablet, desktop): list on the left,
///     player on the right.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    context.read<SearchBloc>().add(SearchQueryChanged(value));
  }

  void _onClear() {
    _controller.clear();
    context.read<SearchBloc>().add(const SearchQueryChanged(''));
  }

  Future<void> _refresh() async {
    context.read<SearchBloc>().add(const SearchRefreshRequested());
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final r = ResponsiveInfo.of(context);

          if (r.useTwoPane) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _ListPane(
                    controller: _controller,
                    onChanged: _onChanged,
                    onClear: _onClear,
                    onRefresh: _refresh,
                    compactHeader: r.isShortHeight,
                  ),
                ),
                Container(
                  width: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                const Expanded(flex: 2, child: _PlayerPane()),
              ],
            );
          }

          return _ListPane(
            controller: _controller,
            onChanged: _onChanged,
            onClear: _onClear,
            onRefresh: _refresh,
            compactHeader: r.isShortHeight,
          );
        },
      ),
    );
  }
}

class _ListPane extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;
  final bool compactHeader;

  const _ListPane({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onRefresh,
    required this.compactHeader,
  });

  @override
  State<_ListPane> createState() => _ListPaneState();
}

class _ListPaneState extends State<_ListPane> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Debounced load-more: fires at most once per 200 ms when within 400 px of
  /// the bottom. This prevents rapid repeated events while momentum-scrolling.
  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.extentAfter < 400) {
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          context.read<SearchBloc>().add(const SearchLoadMoreRequested());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Auto-save last-played whenever the player position changes significantly.
    return BlocListener<PlayerBloc, PlayerState>(
      listenWhen: (prev, curr) =>
          curr.hasTrack &&
          curr.isPlaying &&
          (curr.position - prev.position).inSeconds.abs() >= 5,
      listener: (context, playerState) {
        final track = playerState.track;
        if (track == null) return;
        context.read<BookmarkBloc>().add(
          BookmarkLastPlayedSaveRequested(
            surahNumber: track.surah.number,
            editionId: track.edition.identifier,
            positionMs: playerState.position.inMilliseconds,
          ),
        );
      },
      child: Column(
        children: [
          SearchHeader(
            controller: widget.controller,
            onChanged: widget.onChanged,
            onClear: widget.onClear,
            compact: widget.compactHeader,
            trailing: _ContinueListeningChip(l10n: l10n),
            actions: _SettingsButton(l10n: l10n),
          ),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              buildWhen: (a, b) =>
                  a.status != b.status ||
                  a.surahs != b.surahs ||
                  a.visibleCount != b.visibleCount ||
                  a.errorMessage != b.errorMessage,
              builder: (context, state) {
                return RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: _ResultsList(
                    state: state,
                    scrollController: _scrollController,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Continue listening" chip — only shown when a last-played bookmark exists.
/// Rendered below the search field as the SearchHeader [trailing] widget.
class _ContinueListeningChip extends StatelessWidget {
  final AppLocalizations l10n;
  const _ContinueListeningChip({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      buildWhen: (prev, curr) => prev.lastPlayed != curr.lastPlayed,
      builder: (context, bState) {
        final lp = bState.lastPlayed;
        if (lp == null) return const SizedBox.shrink();
        return ActionChip(
          avatar: const Icon(Icons.play_circle_outline, size: 18),
          label: Text(
            l10n.continueListening,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () {
            final searchState = context.read<SearchBloc>().state;
            final surah = searchState.surahs.cast<Surah?>().firstWhere(
              (s) => s?.number == lp.surahNumber,
              orElse: () => null,
            );
            if (surah == null) return;

            final playerState = context.read<PlayerBloc>().state;
            final sameTrack =
                playerState.track?.surah.number == lp.surahNumber &&
                playerState.track?.edition.identifier == lp.editionId;

            if (!sameTrack) {
              // Different or no track — load it and restore the saved position.
              final reciter = searchState.reciters.cast<Edition?>().firstWhere(
                (e) => e?.identifier == lp.editionId,
                orElse: () => null,
              );
              if (reciter == null) return;
              context.read<PlayerBloc>().add(
                PlayerTrackSelectRequested(
                  Track(surah: surah, edition: reciter),
                ),
              );
              if (lp.positionMs > 0) {
                context.read<PlayerBloc>().add(
                  PlayerSeekRequested(Duration(milliseconds: lp.positionMs)),
                );
              }
            }
            // Navigate to the surah detail page whether or not we reloaded.
            unawaited(SurahDetailPage.show(context, surah));
          },
        );
      },
    );
  }
}

/// Settings icon placed at the top-right of the SearchHeader logo row.
class _SettingsButton extends StatelessWidget {
  final AppLocalizations l10n;
  const _SettingsButton({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined, color: Colors.white),
      tooltip: l10n.settings,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<BookmarkBloc>()),
              BlocProvider.value(value: context.read<SleepTimerBloc>()),
            ],
            child: const SettingsScreen(),
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final SearchState state;
  final ScrollController scrollController;
  const _ResultsList({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SearchStatus.initial:
      case SearchStatus.loading:
        if (state.surahs.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 8,
            itemBuilder: (_, _) => const TrackTileShimmer(),
          );
        }
        break;
      case SearchStatus.failure:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: EmptyStateView(
                icon: Icons.cloud_off_rounded,
                title: 'Something went wrong',
                subtitle: state.errorMessage,
                actionLabel: 'Try again',
                onAction: () => context.read<SearchBloc>().add(
                  const SearchRefreshRequested(),
                ),
              ),
            ),
          ],
        );
      case SearchStatus.refreshing:
      case SearchStatus.success:
        if (state.surahs.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: EmptyStateView(
                  icon: Icons.search_off_rounded,
                  title: state.query.isEmpty
                      ? 'No surahs available'
                      : 'No results for "${state.query}"',
                  subtitle: 'Try a different surah name or number.',
                ),
              ),
            ],
          );
        }
        break;
    }

    final visible = state.visibleSurahs;
    final hasMore = state.hasMore;
    final showQuote = state.query.trim().isEmpty;
    // Extra items at the top when not searching:
    //   index 0 → LastActivityCard (self-hides when no activity)
    //   index 1 → QuoteCard
    final extraCount = showQuote ? 2 : 0;

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.track?.id != curr.track?.id ||
          prev.isPlaying != curr.isPlaying ||
          prev.isLoading != curr.isLoading,
      builder: (context, playerState) {
        return ListView.builder(
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: visible.length + extraCount + 1,
          // Disable defaults — we add RepaintBoundary manually and have no
          // KeepAlive widgets, so these would be wasted overhead.
          addRepaintBoundaries: false,
          addAutomaticKeepAlives: false,
          cacheExtent: 400,
          itemBuilder: (context, index) {
            if (showQuote && index == 0) {
              return const LastActivityCard();
            }
            if (showQuote && index == 1) {
              return const RepaintBoundary(child: QuoteCard());
            }

            final adjustedIndex = showQuote ? index - 2 : index;

            if (adjustedIndex == visible.length) {
              return _PaginationFooter(
                hasMore: hasMore,
                shown: visible.length,
                total: state.surahs.length,
              );
            }
            final surah = visible[adjustedIndex];
            final isActive = playerState.track?.surah.number == surah.number;
            return RepaintBoundary(
              child: SurahTile(
                surah: surah,
                isActive: isActive,
                isPlaying: isActive && playerState.isPlaying,
                isLoading: isActive && playerState.isLoading,
                // Tap always navigates to the detail page — play is intentional
                // from within SurahDetailPage, not a side-effect of browsing.
                onTap: () => unawaited(SurahDetailPage.show(context, surah)),
              ),
            );
          },
        );
      },
    );
  }
}

/// Simple stateless footer — no side effects, no `initState` loop.
/// Pagination is driven by the [ScrollController] in [_ListPaneState].
class _PaginationFooter extends StatelessWidget {
  final bool hasMore;
  final int shown;
  final int total;

  const _PaginationFooter({
    required this.hasMore,
    required this.shown,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: hasMore
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$shown / $total',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              )
            : Text(
                total > 0 ? '$total surahs' : '',
                style: TextStyle(color: color, fontSize: 12),
              ),
      ),
    );
  }
}

/// Right-hand pane used in the two-pane layout. Shows the player when a
/// track is selected, or a friendly hint otherwise.
class _PlayerPane extends StatelessWidget {
  const _PlayerPane();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocSelector<PlayerBloc, PlayerState, bool>(
            selector: (s) => s.hasTrack,
            builder: (context, hasTrack) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: hasTrack
                  ? const SizedBox.shrink(key: ValueKey('empty'))
                  : const EmptyStateView(
                      key: ValueKey('hint'),
                      icon: Icons.headphones_rounded,
                      title: 'Pick a surah to play',
                      subtitle:
                          'Select any item from the list to start listening.',
                    ),
            ),
          ),
        ),
        const PlayerPanel(isBottomBar: false),
      ],
    );
  }
}
