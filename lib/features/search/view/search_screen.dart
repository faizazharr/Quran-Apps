import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive.dart';
import '../../../data/models/edition.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/track.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../player/bloc/player_bloc.dart';
import '../../player/view/player_panel.dart';
import '../../settings/view/settings_screen.dart';
import '../bloc/search_bloc.dart';
import '../widgets/reciter_picker.dart';
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
    context.read<SearchBloc>().add(const SearchRefreshed());
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

          return Column(
            children: [
              Expanded(
                child: _ListPane(
                  controller: _controller,
                  onChanged: _onChanged,
                  onClear: _onClear,
                  onRefresh: _refresh,
                  compactHeader: r.isShortHeight,
                ),
              ),
              const PlayerPanel(),
            ],
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
          BookmarkLastPlayedSaved(
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
            trailing: _HeaderActions(l10n: l10n),
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

/// Continue chip + Settings icon shown inside the SearchHeader trailing area.
class _HeaderActions extends StatelessWidget {
  final AppLocalizations l10n;
  const _HeaderActions({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Continue listening" chip — only shown when last-played exists.
        BlocBuilder<BookmarkBloc, BookmarkState>(
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
                final Surah? surah = searchState.surahs
                    .cast<Surah?>()
                    .firstWhere(
                      (s) => s?.number == lp.surahNumber,
                      orElse: () => null,
                    );
                final Edition? reciter = searchState.reciters
                    .cast<Edition?>()
                    .firstWhere(
                      (e) => e?.identifier == lp.editionId,
                      orElse: () => null,
                    );
                if (surah == null || reciter == null) return;
                context.read<PlayerBloc>().add(
                  PlayerTrackSelected(Track(surah: surah, edition: reciter)),
                );
                if (lp.positionMs > 0) {
                  context.read<PlayerBloc>().add(
                    PlayerSeekRequested(Duration(milliseconds: lp.positionMs)),
                  );
                }
              },
            );
          },
        ),
        const SizedBox(width: 4),
        // Settings button.
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          tooltip: l10n.settings,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<BookmarkBloc>()),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        ),
      ],
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
                onAction: () =>
                    context.read<SearchBloc>().add(const SearchRefreshed()),
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

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, curr) =>
          prev.track?.id != curr.track?.id ||
          prev.isPlaying != curr.isPlaying ||
          prev.isLoading != curr.isLoading,
      builder: (context, playerState) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.contentMaxWidth,
            ),
            child: ListView.builder(
              controller: scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              // +1 slot for the static footer indicator.
              itemCount: visible.length + 1,
              cacheExtent: 800,
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  return _PaginationFooter(
                    hasMore: hasMore,
                    shown: visible.length,
                    total: state.surahs.length,
                  );
                }
                final surah = visible[index];
                final isActive =
                    playerState.track?.surah.number == surah.number;
                final tileReciterName = isActive
                    ? (playerState.track?.artist ?? '')
                    : '';
                return RepaintBoundary(
                  child: SurahTile(
                    surah: surah,
                    isActive: isActive,
                    isPlaying: isActive && playerState.isPlaying,
                    isLoading: isActive && playerState.isLoading,
                    reciterName: tileReciterName,
                    onTap: () async {
                      final searchBloc = context.read<SearchBloc>();
                      final reciters = searchBloc.state.reciters;
                      if (reciters.isEmpty) return;
                      final picked = await showReciterPicker(
                        context,
                        reciters: reciters,
                        selected: searchBloc.state.selectedReciter,
                        surahName: surah.englishName,
                      );
                      if (picked != null && context.mounted) {
                        searchBloc.add(SearchReciterChanged(picked));
                        context.read<PlayerBloc>().add(
                          PlayerTrackSelected(
                            Track(surah: surah, edition: picked),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
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
    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (s) => s.hasTrack,
      builder: (context, hasTrack) {
        if (!hasTrack) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyStateView(
              icon: Icons.headphones_rounded,
              title: 'Pick a surah to play',
              subtitle: 'Select any item from the list to start listening.',
            ),
          );
        }
        return const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [PlayerPanel()],
        );
      },
    );
  }
}
