import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ayah.dart';
import '../../../data/models/translation.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../player/bloc/player_bloc.dart';
import '../bloc/ayah_bloc.dart';

/// A bottom-sheet panel showing Arabic ayah text (and optional translation)
/// for the currently-playing surah. Open it via [AyahView.show].
class AyahView extends StatelessWidget {
  const AyahView({super.key});

  /// Convenience method: show as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (context, scrollController) {
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
                  Expanded(
                    child: Text(
                      l10n.ayahNumber(0).replaceAll('0', ''),
                      style: Theme.of(context).textTheme.titleMedium,
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

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: state.ayahs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 24, indent: 8, endIndent: 8),
                    itemBuilder: (context, index) {
                      final Ayah ayah = state.ayahs[index];
                      final isActive = index == state.activeIndex;
                      final Translation? translation =
                          state.showTranslation &&
                              index < state.translations.length
                          ? state.translations[index]
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
              ayah.text as String,
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
