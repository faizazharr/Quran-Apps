import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/download_record.dart';
import '../../../data/models/edition.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/track.dart';
import '../../../shared/widgets/player_seek_bar.dart';

import '../../activity/bloc/activity_bloc.dart';
import '../../ayah/bloc/ayah_bloc.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../download/bloc/download_bloc.dart';
import '../../player/bloc/player_bloc.dart';
import '../../search/bloc/search_bloc.dart';
import '../../search/widgets/reciter_picker.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/widgets/sleep_timer_dialog.dart';
import '../../sleep_timer/bloc/sleep_timer_bloc.dart';

// ────────────────────────────────────────────────────────────────────────────
// Page entry point
// ────────────────────────────────────────────────────────────────────────────

/// Full-page surah viewer: hero header, embedded player, and scrollable
/// ayah list. Navigation from [SearchScreen] replaces the old "tap to play"
/// shortcut with an intentional "tap ▶ to play" UX.
class SurahDetailPage extends StatefulWidget {
  final Surah surah;

  const SurahDetailPage({super.key, required this.surah});

  /// Push the page, starting an ayah pre-fetch and threading app-level BLoCs.
  static Future<void> show(BuildContext context, Surah surah) {
    // Pre-fetch ayahs so the list is ready by the time the hero animation ends.
    context.read<AyahBloc>().add(AyahLoadRequested(surah.number, surah: surah));

    // Record "last read" activity timestamp.
    context.read<ActivityBloc>().add(ActivityReadRecorded(DateTime.now()));

    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<SearchBloc>()),
            BlocProvider.value(value: context.read<PlayerBloc>()),
            BlocProvider.value(value: context.read<AyahBloc>()),
            BlocProvider.value(value: context.read<BookmarkBloc>()),
            BlocProvider.value(value: context.read<ActivityBloc>()),
            BlocProvider.value(value: context.read<SettingsBloc>()),
            BlocProvider.value(value: context.read<SleepTimerBloc>()),
            BlocProvider.value(value: context.read<DownloadBloc>()),
          ],
          child: SurahDetailPage(surah: surah),
        ),
      ),
    );
  }

  /// Replace the current page with this surah — used by skip next/prev so
  /// the back button returns to the search screen, not through every skipped
  /// surah.
  static Future<void> showReplace(BuildContext context, Surah surah) {
    context.read<AyahBloc>().add(AyahLoadRequested(surah.number, surah: surah));

    // Record "last read" activity timestamp.
    context.read<ActivityBloc>().add(ActivityReadRecorded(DateTime.now()));

    return Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<SearchBloc>()),
            BlocProvider.value(value: context.read<PlayerBloc>()),
            BlocProvider.value(value: context.read<AyahBloc>()),
            BlocProvider.value(value: context.read<BookmarkBloc>()),
            BlocProvider.value(value: context.read<ActivityBloc>()),
            BlocProvider.value(value: context.read<SettingsBloc>()),
            BlocProvider.value(value: context.read<SleepTimerBloc>()),
            BlocProvider.value(value: context.read<DownloadBloc>()),
          ],
          child: SurahDetailPage(surah: surah),
        ),
      ),
    );
  }

  @override
  State<SurahDetailPage> createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends State<SurahDetailPage> {
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  bool _showScrollTop = false;

  /// Whether the user has collapsed the player bottom sheet.
  /// Starts expanded; resets automatically when the page is rebuilt (e.g.
  /// after a skip-navigate via [SurahDetailPage.showReplace]).
  bool _isSheetHidden = false;

  /// Last position (ms) that was sent as [AyahPositionUpdated]. Used to
  /// throttle dispatches: we only send when ≥1 s of playback has elapsed, OR
  /// when a seek jumps more than 1 s (so seeks always respond immediately).
  int _lastDispatchedPositionMs = -1000;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          context.read<AyahBloc>().add(const AyahLoadMoreRequested());
        }
      });
    }
    final shouldShow = _scroll.offset > 300;
    if (shouldShow != _showScrollTop) {
      setState(() => _showScrollTop = shouldShow);
    }
  }

  Future<void> _pickReciter() async {
    final bloc = context.read<SearchBloc>();
    if (bloc.state.reciters.isEmpty) return;
    final picked = await showReciterPicker(
      context,
      reciters: bloc.state.reciters,
      selected: bloc.state.selectedReciter,
      surahName: widget.surah.englishName,
    );
    if (picked != null && mounted) {
      bloc.add(SearchReciterChanged(picked));
    }
  }

  void _onPlayTap() {
    final reciter = context.read<SearchBloc>().state.selectedReciter;
    if (reciter == null) {
      unawaited(_pickReciter());
      return;
    }
    context.read<PlayerBloc>().add(
      PlayerTrackSelectRequested(Track(surah: widget.surah, edition: reciter)),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget get _scrollTopFab => AnimatedScale(
    scale: _showScrollTop ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 200),
    child: FloatingActionButton.small(
      heroTag: 'scroll_top',
      tooltip: 'Back to top',
      onPressed: () => _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.keyboard_arrow_up_rounded),
    ),
  );

  Widget get _accentLine => Container(
    height: 3,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.55),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ),
    ),
  );

  Widget _ayahPaneWithListener({required bool playerInRightPane}) {
    return BlocListener<PlayerBloc, PlayerState>(
      // Fire on every position change for this surah — includes seeks while
      // paused/loading, not just steady playback ticks.
      listenWhen: (prev, curr) =>
          curr.hasTrack &&
          curr.track?.surah.number == widget.surah.number &&
          curr.position != prev.position,
      listener: (context, playerState) {
        final newMs = playerState.position.inMilliseconds;
        // Throttle to ~1 update/second during steady playback. Still fires
        // immediately when the user seeks (jump > 1 s) so the indicator snaps.
        if ((newMs - _lastDispatchedPositionMs).abs() < 900) return;
        _lastDispatchedPositionMs = newMs;
        context.read<AyahBloc>().add(
          AyahPositionUpdated(
            playerState.position,
            duration: playerState.duration,
          ),
        );
      },
      child: _AyahPane(
        scrollController: _scroll,
        surahNumber: widget.surah.number,
        surah: widget.surah,
        isSheetHidden: _isSheetHidden,
        playerInRightPane: playerInRightPane,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveInfo.of(context);
    return r.useTwoPane ? _buildTwoPane(context, r) : _buildCompact(context);
  }

  /// Compact (phone) layout: header on top, ayah list below, player as a
  /// collapsible bottom sheet.
  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: _scrollTopFab,
      bottomSheet: _EmbeddedPlayerSheet(
        surahNumber: widget.surah.number,
        isHidden: _isSheetHidden,
        onToggle: () => setState(() => _isSheetHidden = !_isSheetHidden),
      ),
      body: Column(
        children: [
          _GradientHero(
            surah: widget.surah,
            onPickReciter: _pickReciter,
            onPlayTap: _onPlayTap,
          ),
          _accentLine,
          Expanded(child: _ayahPaneWithListener(playerInRightPane: false)),
        ],
      ),
    );
  }

  /// Two-pane (tablet / landscape) layout: scrollable ayah list on the left,
  /// sticky hero header + player controls on the right.
  Widget _buildTwoPane(BuildContext context, ResponsiveInfo r) {
    final scheme = Theme.of(context).colorScheme;
    // Right panel is wider on expanded screens, narrower on medium.
    final rightWidth = r.isExpanded ? 360.0 : 300.0;

    return Scaffold(
      backgroundColor: scheme.surface,
      floatingActionButton: _scrollTopFab,
      // Keep the FAB over the ayah list (left side), not the player controls
      // (right side). startFloat = bottom-left corner.
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: scrollable ayah list ──────────────────────────────────
          Expanded(child: _ayahPaneWithListener(playerInRightPane: true)),
          // ── Separator ───────────────────────────────────────────────────
          Container(
            width: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          // ── Right: single seamless gradient panel ──────────────────────
          // The entire right column uses one continuous gradient so there is
          // no dead gray gap between the hero and the player controls.
          SizedBox(
            width: rightWidth,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero header — background suppressed; parent gradient shows.
                  _GradientHero(
                    surah: widget.surah,
                    onPickReciter: _pickReciter,
                    onPlayTap: _onPlayTap,
                    showBackground: false,
                    roundedBottom: false,
                  ),
                  // Bookmark + sleep timer — shown only when this surah is
                  // actively playing so the actions have meaningful context.
                  _TabletActionRow(surah: widget.surah),
                  // Decorative faded Arabic surah name fills the remaining
                  // vertical space so nothing is wasted.
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.surah.name,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Scheherazade New',
                              fontSize: 72,
                              height: 1.5,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Player controls (seek bar + buttons) — shown only when this
                  // surah is the active track; gracefully absent otherwise.
                  _TabletPlayerCard(surahNumber: widget.surah.number),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Gradient hero header
// ────────────────────────────────────────────────────────────────────────────

class _GradientHero extends StatelessWidget {
  final Surah surah;
  final VoidCallback onPickReciter;
  final VoidCallback onPlayTap;

  /// When false the gradient Container is omitted — the parent provides the
  /// background (used in the tablet right-panel layout where the entire column
  /// is already a single gradient container).
  final bool showBackground;

  /// Round the bottom corners — only meaningful when [showBackground] is true.
  /// Set false when the hero is part of a larger panel (tablet layout).
  final bool roundedBottom;

  const _GradientHero({
    required this.surah,
    required this.onPickReciter,
    required this.onPlayTap,
    this.showBackground = true,
    this.roundedBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final pad = EdgeInsets.fromLTRB(20, topPad + 8, 20, 22);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row 1: back button ↔ Arabic name ─────────────────────────────
        // The Arabic name lives here so the identity block below has full
        // width for the (dominant) English title — no more cramped inline.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CircleBackButton(),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                surah.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Scheherazade New',
                  fontSize: 22,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Row 2: number badge + English title / meta ────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Number badge — FittedBox handles 3-digit numbers (100–114).
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '${surah.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.englishName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    surah.englishNameTranslation,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MetaBadge('${surah.numberOfAyahs} Ayahs'),
                      _MetaBadge(surah.revelationType),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Row 3: reciter chip + download + play ────────────────────────
        Row(
          children: [
            Expanded(child: _ReciterChip(onTap: onPickReciter)),
            const SizedBox(width: 8),
            _DownloadButton(surah: surah),
            const SizedBox(width: 8),
            _PlayButton(surahNumber: surah.number, onTap: onPlayTap),
          ],
        ),
      ],
    ); // end column

    if (!showBackground) return Padding(padding: pad, child: column);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: roundedBottom
            ? const BorderRadius.vertical(bottom: Radius.circular(28))
            : null,
      ),
      padding: pad,
      child: column,
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 44×44 dp minimum tap area (accessibility requirement).
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill badge for metadata labels (ayah count, revelation type).
class _MetaBadge extends StatelessWidget {
  final String label;
  const _MetaBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Tappable reciter chip — always visible, opens [ReciterPicker] on tap.
class _ReciterChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ReciterChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SearchBloc, SearchState, Edition?>(
      selector: (s) => s.selectedReciter,
      builder: (context, reciter) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_rounded, color: Colors.white70, size: 15),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    reciter?.englishName ?? 'Select Reciter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact play/pause button for the hero header.
class _PlayButton extends StatelessWidget {
  final int surahNumber;
  final VoidCallback onTap;
  const _PlayButton({required this.surahNumber, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, _PlayBtnVM>(
      selector: (s) => _PlayBtnVM(
        isThisSurah: s.track?.surah.number == surahNumber,
        isPlaying: s.isPlaying,
        isLoading: s.isLoading,
      ),
      builder: (context, vm) {
        final playing = vm.isThisSurah && vm.isPlaying;
        final loading = vm.isThisSurah && vm.isLoading;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.30),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: loading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    loading ? 'Loading…' : (playing ? 'Pause' : 'Play'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayBtnVM extends Equatable {
  final bool isThisSurah;
  final bool isPlaying;
  final bool isLoading;
  const _PlayBtnVM({
    required this.isThisSurah,
    required this.isPlaying,
    required this.isLoading,
  });
  @override
  List<Object?> get props => [isThisSurah, isPlaying, isLoading];
}

// ────────────────────────────────────────────────────────────────────────────
// Embedded player — seek bar + transport controls
// Appears below the hero header only when this surah is the active track.
// ────────────────────────────────────────────────────────────────────────────

/// Persistent bottom sheet that slides up when this surah is the active
/// player track. Rounded top corners + brand gradient match the hero style.
///
/// When [isHidden] is `true` the full controls collapse to a compact mini-tab
/// so the user can see the ayah list unobstructed — tapping the tab restores
/// the full sheet. Calling [onToggle] flips the hidden state.
class _EmbeddedPlayerSheet extends StatelessWidget {
  final int surahNumber;
  final bool isHidden;
  final VoidCallback onToggle;

  const _EmbeddedPlayerSheet({
    required this.surahNumber,
    required this.isHidden,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (s) => s.track?.surah.number == surahNumber,
      builder: (context, isActive) => AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        child: !isActive
            ? const SizedBox.shrink()
            : isHidden
            ? _PlayerMiniTab(onShow: onToggle)
            : _EmbeddedPlayerSheetContent(onHide: onToggle),
      ),
    );
  }
}

// ── Full player sheet ─────────────────────────────────────────────────────────

class _EmbeddedPlayerSheetContent extends StatelessWidget {
  final VoidCallback onHide;
  const _EmbeddedPlayerSheetContent({required this.onHide});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: drag handle (centre) + hide button (right)
          Row(
            children: [
              // Spacer to balance the hide button width
              const SizedBox(width: 32),
              Expanded(
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Hide / collapse button
              SizedBox(
                width: 32,
                height: 32,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onHide,
                    child: const Center(
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const RepaintBoundary(child: PlayerSeekBar(compact: true)),
          const SizedBox(height: 2),
          const _EmbeddedControls(),
        ],
      ),
    );
  }
}

// ── Mini-tab shown when the sheet is hidden ───────────────────────────────────

/// Compact strip displayed at the bottom of the screen when the user has
/// collapsed the player sheet. A single tap restores the full controls.
class _PlayerMiniTab extends StatelessWidget {
  final VoidCallback onShow;
  const _PlayerMiniTab({required this.onShow});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onShow,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(18, 10, 14, 10 + bottomPad),
        child: Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            // Show the currently-playing surah name in the mini-tab.
            BlocSelector<PlayerBloc, PlayerState, String>(
              selector: (s) => s.track?.surah.englishName ?? 'Now Playing',
              builder: (context, name) => Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedControls extends StatelessWidget {
  const _EmbeddedControls();

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, _CtrlVM>(
      selector: (s) => _CtrlVM(
        isPlaying: s.isPlaying,
        isLoading: s.isLoading,
        isCompleted: s.status == PlaybackStatus.completed,
        speed: s.speed,
        repeatMode: s.repeatMode,
      ),
      builder: (context, vm) {
        final bloc = context.read<PlayerBloc>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GhostBtn(
              icon: Icons.skip_previous_rounded,
              onTap: () => _skipAdjacent(context, -1),
            ),
            _GhostBtn(
              icon: Icons.replay_10_rounded,
              onTap: () => bloc.add(
                PlayerSeekRequested(
                  bloc.state.position - const Duration(seconds: 10),
                ),
              ),
            ),
            _PrimaryBtn(
              icon: vm.isCompleted
                  ? Icons.replay_rounded
                  : (vm.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
              loading: vm.isLoading,
              onTap: () {
                if (vm.isCompleted) {
                  bloc.add(const PlayerSeekRequested(Duration.zero));
                  bloc.add(const PlayerPlayRequested());
                } else {
                  bloc.add(
                    vm.isPlaying
                        ? const PlayerPauseRequested()
                        : const PlayerPlayRequested(),
                  );
                }
              },
            ),
            _GhostBtn(
              icon: Icons.forward_10_rounded,
              onTap: () => bloc.add(
                PlayerSeekRequested(
                  bloc.state.position + const Duration(seconds: 10),
                ),
              ),
            ),
            _GhostBtn(
              icon: Icons.skip_next_rounded,
              onTap: () => _skipAdjacent(context, 1),
            ),
            // Repeat toggle
            Tooltip(
              message: vm.repeatMode == PlayerRepeatMode.one
                  ? 'Repeat: On'
                  : 'Repeat: Off',
              child: _GhostBtn(
                icon: Icons.repeat_one_rounded,
                onTap: () => bloc.add(const PlayerRepeatModeChanged()),
                active: vm.repeatMode == PlayerRepeatMode.one,
              ),
            ),
            _SpeedPill(
              speed: vm.speed,
              speeds: _speeds,
              onChanged: (s) => bloc.add(PlayerSpeedChanged(s)),
            ),
          ],
        );
      },
    );
  }
}

class _CtrlVM extends Equatable {
  final bool isPlaying;
  final bool isLoading;
  final bool isCompleted;
  final double speed;
  final PlayerRepeatMode repeatMode;
  const _CtrlVM({
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
    required this.speed,
    required this.repeatMode,
  });
  @override
  List<Object?> get props => [
    isPlaying,
    isLoading,
    isCompleted,
    speed,
    repeatMode,
  ];
}

void _skipAdjacent(BuildContext context, int delta) {
  final player = context.read<PlayerBloc>();
  final track = player.state.track;
  if (track == null) return;
  final surahs = context.read<SearchBloc>().state.surahs;
  final idx = surahs.indexWhere((s) => s.number == track.surah.number);
  if (idx == -1) return;
  final next = idx + delta;
  if (next < 0 || next >= surahs.length) return;
  final nextSurah = surahs[next];
  // Start playback immediately then navigate to the new surah's detail page.
  // pushReplacement keeps the back-stack clean — one Back tap returns to the
  // search screen rather than the previous surah.
  player.add(
    PlayerTrackSelectRequested(Track(surah: nextSurah, edition: track.edition)),
  );
  unawaited(SurahDetailPage.showReplace(context, nextSurah));
}

class _GhostBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _GhostBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    // 44×44 dp minimum tap area (WCAG / Material accessibility guideline).
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: active ? AppColors.accent : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn({
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onTap,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(icon, color: AppColors.primary, size: 28),
          ),
        ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  final double speed;
  final List<double> speeds;
  final ValueChanged<double> onChanged;
  const _SpeedPill({
    required this.speed,
    required this.speeds,
    required this.onChanged,
  });

  String _label(double s) =>
      s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final next = speeds[(speeds.indexOf(speed) + 1) % speeds.length];
        onChanged(next);
      },
      onLongPress: () async {
        final box = context.findRenderObject()! as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final screen = MediaQuery.sizeOf(context);
        final menuH = speeds.length * 48.0;
        final top = (offset.dy - menuH).clamp(8.0, screen.height - menuH - 8.0);
        final picked = await showMenu<double>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            top,
            offset.dx + box.size.width,
            top + menuH,
          ),
          items: speeds
              .map(
                (s) => PopupMenuItem<double>(
                  value: s,
                  child: Row(
                    children: [
                      if (s == speed)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(_label(s)),
                    ],
                  ),
                ),
              )
              .toList(),
        );
        if (picked != null) onChanged(picked);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: speed != 1.0
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _label(speed),
          style: TextStyle(
            color: Colors.white,
            fontWeight: speed != 1.0 ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Ayah list pane
// ────────────────────────────────────────────────────────────────────────────

/// Full player sheet height (seek bar + controls + padding + drag handle).
/// The ayah list uses this as bottom padding so the last ayah stays visible.
const double _kPlayerSheetHeight = 186.0;

/// Height of the mini-tab shown when the sheet is collapsed.
const double _kPlayerMiniTabHeight = 52.0;

class _AyahPane extends StatefulWidget {
  final ScrollController scrollController;
  final int surahNumber;
  final Surah surah;
  final bool isSheetHidden;

  /// True when the player is in the right-side column (tablet) — suppresses
  /// the extra bottom padding that reserves space for the bottom sheet.
  final bool playerInRightPane;

  const _AyahPane({
    required this.scrollController,
    required this.surahNumber,
    required this.surah,
    required this.isSheetHidden,
    this.playerInRightPane = false,
  });

  @override
  State<_AyahPane> createState() => _AyahPaneState();
}

class _AyahPaneState extends State<_AyahPane> {
  /// One key per rendered ayah card — used by [_scrollToActive] to call
  /// [Scrollable.ensureVisible] so the highlighted ayah stays on-screen.
  final Map<int, GlobalKey> _itemKeys = {};

  GlobalKey _keyFor(int index) => _itemKeys.putIfAbsent(index, GlobalKey.new);

  void _scrollToActive(int index) {
    final key = _itemKeys[index];
    if (key?.currentContext == null) {
      // Item may not have rendered yet (lazy list just expanded). Retry once
      // after the next frame so Flutter has a chance to build the new items.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final retryKey = _itemKeys[index];
        if (retryKey?.currentContext == null) return;
        unawaited(
          Scrollable.ensureVisible(
            retryKey!.currentContext!,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            alignment: 0.25,
          ),
        );
      });
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        // Keep the active ayah roughly in the upper-third of the viewport so
        // there is always content visible below it.
        alignment: 0.25,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = ResponsiveInfo.of(context);
    // On non-compact screens, cap content at contentMaxWidth and centre it.
    // Medium two-pane left panes > 720 dp (e.g. 1020 dp total) benefit from
    // this; smaller panels are already narrower than the cap so it's a no-op.
    final useMaxWidth = !r.isCompact;

    return BlocListener<AyahBloc, AyahState>(
      listenWhen: (prev, curr) =>
          curr.activeIndex != prev.activeIndex && curr.activeIndex >= 0,
      listener: (context, state) => _scrollToActive(state.activeIndex),
      child: BlocSelector<PlayerBloc, PlayerState, bool>(
        selector: (s) => s.track?.surah.number == widget.surahNumber,
        builder: (context, isPlayerActive) => BlocBuilder<AyahBloc, AyahState>(
          builder: (context, state) {
            // Shimmer skeleton while ayahs are loading.
            if (state.status == AyahStatus.initial ||
                state.status == AyahStatus.loading) {
              return _AyahShimmerList(scheme: scheme, useMaxWidth: useMaxWidth);
            }

            // Error state
            if (state.status == AyahStatus.error) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: scheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage ?? 'Failed to load ayahs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.read<AyahBloc>().add(
                            AyahLoadRequested(
                              widget.surahNumber,
                              surah: widget.surah,
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final visible = state.visibleAyahs;
            final translations = state.visibleTranslations;
            final hasMore = state.hasMore;

            Widget content = Column(
              children: [
                // Translation toggle bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        '${state.totalAyahs} Ayahs',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: scheme.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const Spacer(),
                      BlocBuilder<AyahBloc, AyahState>(
                        buildWhen: (p, c) =>
                            p.showTranslation != c.showTranslation,
                        builder: (context, s) => TextButton.icon(
                          icon: const Icon(Icons.translate_rounded, size: 15),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Translation',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                s.showTranslation
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 14,
                              ),
                            ],
                          ),
                          onPressed: () => context.read<AyahBloc>().add(
                            const AyahTranslationToggled(),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),

                // Ayah list — extra bottom padding reserves space for the
                // player sheet on phone; no extra padding on tablet since the
                // player is in the right column.
                Expanded(
                  child: ListView.separated(
                    controller: widget.scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      widget.playerInRightPane
                          ? 12.0
                          : (isPlayerActive
                                ? (widget.isSheetHidden
                                      ? _kPlayerMiniTabHeight
                                      : _kPlayerSheetHeight)
                                : 12.0),
                    ),
                    itemCount: visible.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => Divider(
                      height: 24,
                      indent: 8,
                      endIndent: 8,
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    itemBuilder: (context, i) {
                      if (i == visible.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final ayah = visible[i];
                      final translation =
                          state.showTranslation && i < translations.length
                          ? translations[i].text
                          : null;
                      // KeyedSubtree lets _scrollToActive call
                      // Scrollable.ensureVisible on the rendered item.
                      return KeyedSubtree(
                        key: _keyFor(i),
                        child:
                            BlocSelector<SettingsBloc, SettingsState, double>(
                              selector: (s) => s.settings.arabicFontSize,
                              builder: (context, arabicFontSize) => _AyahCard(
                                ayah: ayah,
                                translation: translation,
                                isActive: i == state.activeIndex,
                                scheme: scheme,
                                arabicFontSize: arabicFontSize,
                              ),
                            ),
                      );
                    },
                  ),
                ),
              ],
            );

            // On expanded (tablet/desktop) screens, centre the list column and cap
            // its width so reading lines stay comfortable (Breakpoints.contentMaxWidth).
            if (useMaxWidth) {
              content = Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.contentMaxWidth,
                  ),
                  child: content,
                ),
              );
            }

            return content;
          },
        ), // BlocBuilder<AyahBloc>
      ), // BlocSelector<PlayerBloc>
    ); // BlocListener<AyahBloc>
  }
}

// ── Tablet-only player card ──────────────────────────────────────────────────

/// Player seek bar + controls in the tablet right-side column.
/// The parent Container already provides the gradient background, so this
/// widget renders as a flat panel with just a subtle top divider.
/// Hidden entirely when [surahNumber] is not the active track.
// ── Tablet action row (bookmark + sleep timer) ───────────────────────────────

/// Row of quick-action buttons shown in the tablet right panel when this surah
/// is the active track. Hidden otherwise — actions require a live position.
class _TabletActionRow extends StatelessWidget {
  final Surah surah;
  const _TabletActionRow({required this.surah});

  int get surahNumber => surah.number;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (s) => s.hasTrack && s.track?.surah.number == surahNumber,
      builder: (context, isActive) {
        if (!isActive) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WhiteCircleBtn(
                icon: Icons.bookmark_add_outlined,
                tooltip: 'Bookmark position',
                onTap: () {
                  final state = context.read<PlayerBloc>().state;
                  final track = state.track;
                  if (track == null) return;
                  context.read<BookmarkBloc>().add(
                    BookmarkAddRequested(
                      surahNumber: track.surah.number,
                      editionId: track.edition.identifier,
                      positionMs: state.position.inMilliseconds,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bookmarked'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              BlocSelector<SleepTimerBloc, SleepTimerState, bool>(
                selector: (s) => s.isActive,
                builder: (context, timerActive) => _WhiteCircleBtn(
                  icon: timerActive
                      ? Icons.bedtime_rounded
                      : Icons.bedtime_outlined,
                  tooltip: timerActive ? 'Sleep timer active' : 'Sleep timer',
                  active: timerActive,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(
                          value: context.read<SleepTimerBloc>(),
                        ),
                      ],
                      child: const SleepTimerDialog(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _DownloadButton(surah: surah),
            ],
          ),
        );
      },
    );
  }
}

// ── Download button (hero + tablet action row) ────────────────────────────────

/// Shows the download status for the current (surah, selected-reciter) pair
/// and lets the user enqueue, cancel or delete a download.
class _DownloadButton extends StatelessWidget {
  final Surah surah;
  const _DownloadButton({required this.surah});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) => p.selectedReciter != c.selectedReciter,
      builder: (context, searchState) {
        final reciter = searchState.selectedReciter;
        if (reciter == null) return const SizedBox.shrink();

        return BlocSelector<DownloadBloc, DownloadState, DownloadRecord?>(
          selector: (s) => s.recordFor(surah.number, reciter.identifier),
          builder: (context, record) {
            final isCompleted = record?.isCompleted ?? false;
            final isDownloading = record?.isDownloading ?? false;

            if (isDownloading) {
              return Tooltip(
                message: 'Tap to cancel download',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: record!.progress > 0 ? record.progress : null,
                        strokeWidth: 2.5,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      GestureDetector(
                        onTap: () => context.read<DownloadBloc>().add(
                          DownloadCancelRequested(
                            surahNumber: surah.number,
                            editionId: reciter.identifier,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Tooltip(
              message: isCompleted
                  ? 'Downloaded — tap to remove'
                  : 'Download for offline',
              child: SizedBox(
                width: 44,
                height: 44,
                child: Material(
                  color: isCompleted
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.18),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (isCompleted) {
                        context.read<DownloadBloc>().add(
                          DownloadDeleteRequested(
                            surahNumber: surah.number,
                            editionId: reciter.identifier,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Download removed'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        final audioUrl = Track(
                          surah: surah,
                          edition: reciter,
                        ).audioUrl;
                        context.read<DownloadBloc>().add(
                          DownloadEnqueueRequested(
                            surahNumber: surah.number,
                            editionId: reciter.identifier,
                            audioUrl: audioUrl,
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloading ${surah.englishName}…'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Center(
                      child: Icon(
                        isCompleted
                            ? Icons.file_download_done_rounded
                            : Icons.download_rounded,
                        color: isCompleted ? AppColors.accent : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WhiteCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  const _WhiteCircleBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn = SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: active ? AppColors.accent : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

// ── Tablet player card (seek bar + controls) ─────────────────────────────────

class _TabletPlayerCard extends StatelessWidget {
  final int surahNumber;
  const _TabletPlayerCard({required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (s) => s.track?.surah.number == surahNumber,
      builder: (context, isActive) {
        if (!isActive) return const SizedBox.shrink();
        final bottomPad = MediaQuery.of(context).padding.bottom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtle separator — lighter than the gradient to add visual depth.
            Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + bottomPad),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(child: PlayerSeekBar(compact: true)),
                  SizedBox(height: 2),
                  _EmbeddedControls(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Ayah shimmer skeleton ────────────────────────────────────────────────────

/// Placeholder skeleton shown while ayahs are being fetched.
/// Mirrors the visual shape of [_AyahCard] so the layout does not jump.
class _AyahShimmerList extends StatelessWidget {
  final ColorScheme scheme;
  final bool useMaxWidth;
  const _AyahShimmerList({required this.scheme, required this.useMaxWidth});

  @override
  Widget build(BuildContext context) {
    Widget list = ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, _) => Divider(
        height: 24,
        indent: 8,
        endIndent: 8,
        color: scheme.outlineVariant.withValues(alpha: 0.35),
      ),
      itemBuilder: (_, i) => _AyahCardShimmer(scheme: scheme, seed: i),
    );

    if (useMaxWidth) {
      list = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Breakpoints.contentMaxWidth,
          ),
          child: list,
        ),
      );
    }

    return list;
  }
}

class _AyahCardShimmer extends StatelessWidget {
  final ColorScheme scheme;
  final int seed;
  const _AyahCardShimmer({required this.scheme, required this.seed});

  @override
  Widget build(BuildContext context) {
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final light = scheme.surfaceContainerHighest.withValues(alpha: 0.30);

    // Vary Arabic text-block height slightly so it looks organic.
    final textH = 60.0 + (seed % 3) * 20.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verse number badge placeholder — right-aligned
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 40,
              height: 20,
              decoration: BoxDecoration(
                color: light,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Arabic text block
          Container(
            height: textH,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          // Translation line
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: light,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.65,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: light,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final String? translation;
  final bool isActive;
  final ColorScheme scheme;
  final double arabicFontSize;

  const _AyahCard({
    required this.ayah,
    required this.translation,
    required this.isActive,
    required this.scheme,
    required this.arabicFontSize,
  });

  void _showCopyMenu(BuildContext outerCtx) {
    unawaited(
      showModalBottomSheet<void>(
        context: outerCtx,
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetCtx,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Arabic text'),
                onTap: () {
                  unawaited(Clipboard.setData(ClipboardData(text: ayah.text)));
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(outerCtx).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              if (translation != null)
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: const Text('Copy with translation'),
                  onTap: () {
                    unawaited(
                      Clipboard.setData(
                        ClipboardData(text: '${ayah.text}\n\n$translation'),
                      ),
                    );
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showCopyMenu(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: scheme.primary.withValues(alpha: 0.35))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Verse number badge — right-aligned per mushaf convention.
            // Directionality(rtl) is required so that ﴿ ﴾ ornament brackets
            // render correctly (they are Arabic RTL codepoints).
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    '﴿${ayah.numberInSurah}﴾',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontFamily: 'Scheherazade New',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Arabic text — RTL, justified
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ayah.text,
                style: TextStyle(
                  fontFamily: 'Scheherazade New',
                  fontSize: arabicFontSize,
                  height: 1.9,
                  color: isActive ? scheme.primary : scheme.onSurface,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.justify,
              ),
            ),

            // Optional translation
            if (translation != null) ...[
              const SizedBox(height: 8),
              Text(
                translation!,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ), // Column
      ), // AnimatedContainer
    ); // GestureDetector
  }
}
