import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ayah.dart';
import '../../../data/models/surah.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../player/bloc/player_bloc.dart';
import '../bloc/ayah_bloc.dart';

/// A bottom-sheet panel showing Arabic ayah text (and optional translation).
/// Can be opened from the player panel (while playing) or directly from a
/// surah tile (to read without playing). Use [AyahView.show].
class AyahView extends StatefulWidget {
  const AyahView({super.key});

  /// Show the Ayah reader as a modal bottom sheet.
  /// If [surahNumber] is provided, triggers a fresh load; otherwise the
  /// sheet shows whatever is already loaded in [AyahBloc] (e.g. from player).
  /// Pass [surah] for a richer header (name, count).
  static Future<void> show(
    BuildContext context, {
    int? surahNumber,
    Surah? surah,
  }) {
    if (surahNumber != null) {
      context.read<AyahBloc>().add(
        AyahLoadRequested(surahNumber, surah: surah),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<AyahBloc>()),
          BlocProvider.value(value: context.read<PlayerBloc>()),
        ],
        child: const AyahView(),
      ),
    );
  }

  @override
  State<AyahView> createState() => _AyahViewState();
}

class _AyahViewState extends State<AyahView> {
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

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.extentAfter < 300) {
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          context.read<AyahBloc>().add(const AyahLoadMoreRequested());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (context, sheetScrollController) {
        // Use the sheet's scroll controller for the sheet handle dragging,
        // but our own controller for load-more detection on the list.
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BlocSelector<AyahBloc, AyahState, _HeaderVM>(
                      selector: (s) => _HeaderVM(
                        englishName: s.surahEnglishName,
                        arabicName: s.surahArabicName,
                        number: s.surahNumber,
                        totalAyahs: s.totalAyahs,
                      ),
                      builder: (context, vm) {
                        final title = vm.englishName.isNotEmpty
                            ? vm.englishName
                            : (vm.number > 0 ? 'Surah ${vm.number}' : 'Quran');
                        final subtitle = vm.totalAyahs > 0
                            ? 'Surah ${vm.number} • ${vm.totalAyahs} Ayah'
                            : '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (vm.arabicName.isNotEmpty)
                                  Text(
                                    vm.arabicName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontFamily: 'Amiri',
                                          fontSize: 18,
                                        ),
                                  ),
                              ],
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Translation toggle button
                  BlocBuilder<AyahBloc, AyahState>(
                    buildWhen: (p, c) => p.showTranslation != c.showTranslation,
                    builder: (context, state) {
                      return TextButton.icon(
                        icon: Icon(
                          state.showTranslation
                              ? Icons.translate
                              : Icons.translate_outlined,
                          size: 18,
                        ),
                        label: Text(
                          state.showTranslation
                              ? l10n.hideTranslation
                              : l10n.showTranslation,
                        ),
                        onPressed: () => context.read<AyahBloc>().add(
                          const AyahTranslationToggled(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Ayah list
            Expanded(
              child: BlocBuilder<AyahBloc, AyahState>(
                builder: (context, state) {
                  if (state.status == AyahStatus.loading ||
                      state.status == AyahStatus.initial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.status == AyahStatus.error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.errorMessage ?? 'Failed to load ayahs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    );
                  }

                  if (state.ayahs.isEmpty) {
                    return const Center(child: Text('No ayahs available.'));
                  }

                  final visible = state.visibleAyahs;
                  final hasMore = state.hasMore;

                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: visible.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const Divider(height: 24, indent: 8, endIndent: 8),
                    itemBuilder: (context, index) {
                      if (index == visible.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final ayah = visible[index];
                      final isActive = index == state.activeIndex;
                      final translation =
                          state.showTranslation &&
                              index < state.visibleTranslations.length
                          ? state.visibleTranslations[index]
                          : null;

                      return _AyahTile(
                        ayah: ayah,
                        translation: translation?.text,
                        isActive: isActive,
                        scheme: scheme,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AyahTile extends StatelessWidget {
  final Ayah ayah;
  final String? translation;
  final bool isActive;
  final ColorScheme scheme;

  const _AyahTile({
    required this.ayah,
    required this.translation,
    required this.isActive,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isActive
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ayah number badge
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '﴿${ayah.numberInSurah}﴾',
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontFamily: 'Scheherazade New',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Arabic text (right-to-left)
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

class _HeaderVM {
  final String englishName;
  final String arabicName;
  final int number;
  final int totalAyahs;
  const _HeaderVM({
    required this.englishName,
    required this.arabicName,
    required this.number,
    required this.totalAyahs,
  });
}
