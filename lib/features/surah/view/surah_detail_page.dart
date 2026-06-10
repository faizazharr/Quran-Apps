import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/edition.dart';
import '../../../data/models/surah.dart';
import '../../../data/models/track.dart';
import '../../../shared/widgets/player_seek_bar.dart';
import '../../activity/bloc/activity_bloc.dart';
import '../../ayah/bloc/ayah_bloc.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../player/bloc/player_bloc.dart';
import '../../search/bloc/search_bloc.dart';
import '../../search/widgets/reciter_picker.dart';

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

  /// Whether the user has collapsed the player bottom sheet.
  /// Starts expanded; resets automatically when the page is rebuilt (e.g.
  /// after a skip-navigate via [SurahDetailPage.showReplace]).
  bool _isSheetHidden = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Persistent bottom sheet — slides up from below the ayah list when this
      // surah becomes the active player track. The ayah list adds extra bottom
      // padding so the last ayah is never hidden behind the sheet.
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
          // Thin accent line — softens the hero / ayah-list colour boundary.
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.55),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Scrollable ayah list — bottom-padded when the player sheet is open.
          Expanded(
            child: _AyahPane(
              scrollController: _scroll,
              surahNumber: widget.surah.number,
              isSheetHidden: _isSheetHidden,
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

  const _GradientHero({
    required this.surah,
    required this.onPickReciter,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 22),
      child: Column(
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
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

          // ── Row 3: reciter chip + play button ────────────────────────────
          Row(
            children: [
              Expanded(child: _ReciterChip(onTap: onPickReciter)),
              const SizedBox(width: 12),
              _PlayButton(surahNumber: surah.number, onTap: onPlayTap),
            ],
          ),
        ],
      ),
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
  const _CtrlVM({
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
    required this.speed,
  });
  @override
  List<Object?> get props => [isPlaying, isLoading, isCompleted, speed];
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
  const _GhostBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 44×44 dp minimum tap area (WCAG / Material accessibility guideline).
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: Icon(icon, color: Colors.white, size: 20)),
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

class _AyahPane extends StatelessWidget {
  final ScrollController scrollController;
  final int surahNumber;
  final bool isSheetHidden;
  const _AyahPane({
    required this.scrollController,
    required this.surahNumber,
    required this.isSheetHidden,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = ResponsiveInfo.of(context);
    // On wide screens, cap the content column at contentMaxWidth and centre it.
    final useMaxWidth = r.isExpanded;

    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (s) => s.track?.surah.number == surahNumber,
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
                          AyahLoadRequested(state.surahNumber, surah: null),
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
                        icon: Icon(
                          s.showTranslation
                              ? Icons.translate
                              : Icons.translate_outlined,
                          size: 15,
                        ),
                        label: Text(
                          s.showTranslation ? 'Hide' : 'Translation',
                          style: const TextStyle(fontSize: 13),
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

              // Ayah list — extra bottom padding reserves space for the player
              // sheet so the last ayah is never hidden behind it.
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    isPlayerActive
                        ? (isSheetHidden
                              ? _kPlayerMiniTabHeight
                              : _kPlayerSheetHeight)
                        : 12.0,
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
                    return _AyahCard(
                      ayah: ayah,
                      translation: translation,
                      isActive: i == state.activeIndex,
                      scheme: scheme,
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
    ); // BlocSelector<PlayerBloc>
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

  const _AyahCard({
    required this.ayah,
    required this.translation,
    required this.isActive,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? scheme.primary : scheme.surfaceContainerHigh,
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
                fontSize: 26,
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
      ),
    );
  }
}
