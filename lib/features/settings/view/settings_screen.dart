import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/translation_edition.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../player/bloc/player_bloc.dart';
import '../../search/bloc/search_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/sleep_timer_dialog.dart';

/// Full-page settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = ResponsiveInfo.of(context);

    return Scaffold(
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = state.settings;

          final maxWidth = !r.isCompact ? Breakpoints.contentMaxWidth : null;

          return CustomScrollView(
            slivers: [
              // Gradient SliverAppBar — consistent with other gradient headers.
              SliverAppBar(
                pinned: true,
                title: Text(
                  l10n.settings,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: 0.2,
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    // Match the rounded bottom corners of all other gradient headers.
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                ),
                backgroundColor: Colors.transparent,
                // Reserve space so the rounded corners aren't clipped.
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(12),
                  child: SizedBox(),
                ),
              ),
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth ?? double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Theme ---
                        _SectionHeader(l10n.darkMode),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: SegmentedButton<AppThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: AppThemeMode.system,
                                label: Text(l10n.themeSystem),
                                icon: const Icon(Icons.brightness_auto_rounded),
                              ),
                              ButtonSegment(
                                value: AppThemeMode.light,
                                label: Text(l10n.themeLight),
                                icon: const Icon(Icons.light_mode_rounded),
                              ),
                              ButtonSegment(
                                value: AppThemeMode.dark,
                                label: Text(l10n.themeDark),
                                icon: const Icon(Icons.dark_mode_rounded),
                              ),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (v) {
                              if (v.isNotEmpty) {
                                context.read<SettingsBloc>().add(
                                  SettingsThemeChanged(v.first),
                                );
                              }
                            },
                            style: const ButtonStyle(
                              iconSize: WidgetStatePropertyAll(16),
                              textStyle: WidgetStatePropertyAll(
                                TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 24),

                        // --- Language ---
                        _SectionHeader(l10n.language),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: SegmentedButton<String?>(
                            segments: const [
                              ButtonSegment(
                                value: null,
                                label: Text('Auto'),
                                icon: Icon(Icons.phone_android_rounded),
                              ),
                              ButtonSegment(
                                value: 'en',
                                label: Text('English'),
                                icon: Icon(Icons.language_rounded),
                              ),
                              ButtonSegment(
                                value: 'id',
                                label: Text('Indonesia'),
                                icon: Icon(Icons.language_rounded),
                              ),
                            ],
                            selected: {settings.localeTag},
                            onSelectionChanged: (v) => context
                                .read<SettingsBloc>()
                                .add(SettingsLocaleChanged(v.first)),
                            style: const ButtonStyle(
                              iconSize: WidgetStatePropertyAll(16),
                              textStyle: WidgetStatePropertyAll(
                                TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 24),

                        // --- Translation ---
                        const _SectionHeader('Quran Translation'),
                        _TranslationPicker(
                          current: settings.translationEditionId,
                        ),
                        const Divider(height: 24),

                        // --- Arabic font size ---
                        const _SectionHeader('Ayah Font Size'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.text_fields_rounded, size: 16),
                              Expanded(
                                child: Slider(
                                  value: settings.arabicFontSize,
                                  min: 18,
                                  max: 40,
                                  divisions: 11,
                                  label:
                                      '${settings.arabicFontSize.toInt()} sp',
                                  onChanged: (v) => context
                                      .read<SettingsBloc>()
                                      .add(SettingsArabicFontSizeChanged(v)),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${settings.arabicFontSize.toInt()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Preview
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                              style: TextStyle(
                                fontFamily: 'Scheherazade New',
                                fontSize: settings.arabicFontSize,
                                height: 1.9,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const Divider(height: 24),

                        // --- Sleep Timer ---
                        _SectionHeader(l10n.sleepTimer),
                        ListTile(
                          leading: const Icon(Icons.bedtime_outlined),
                          title: Text(l10n.sleepTimer),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => MultiBlocProvider(
                              providers: [
                                BlocProvider.value(
                                  value: context.read<PlayerBloc>(),
                                ),
                              ],
                              child: const SleepTimerDialog(),
                            ),
                          ),
                        ),
                        const Divider(height: 24),

                        // --- Bookmarks ---
                        const _SectionHeader('Bookmarks'),
                        BlocBuilder<BookmarkBloc, BookmarkState>(
                          builder: (context, bState) {
                            if (bState.bookmarks.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Text(
                                  'No bookmarks saved yet.\nTap the bookmark icon while playing to save a position.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              );
                            }
                            return Column(
                              children: bState.bookmarks.map((b) {
                                // Resolve reciter name from SearchBloc state.
                                final reciterName =
                                    context
                                        .read<SearchBloc>()
                                        .state
                                        .reciters
                                        .where(
                                          (e) => e.identifier == b.editionId,
                                        )
                                        .map((e) => e.englishName)
                                        .firstOrNull ??
                                    b.editionId;
                                final position = DurationFormatter.format(
                                  Duration(milliseconds: b.positionMs),
                                );
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${b.surahNumber}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    'Surah ${b.surahNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$reciterName · $position',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                    onPressed: () => context
                                        .read<BookmarkBloc>()
                                        .add(BookmarkDeleteRequested(b.id!)),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        // bottom breathing room
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TranslationPicker extends StatelessWidget {
  final String current;
  const _TranslationPicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final selected = TranslationEditions.findById(current);
    final label = selected?.label ?? current;

    return ListTile(
      leading: const Icon(Icons.translate_rounded),
      title: const Text('Translation language'),
      subtitle: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<TranslationEdition>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _TranslationPickerSheet(currentId: current),
        );
        if (picked != null && context.mounted) {
          context.read<SettingsBloc>().add(
            SettingsTranslationEditionChanged(picked.id),
          );
        }
      },
    );
  }
}

class _TranslationPickerSheet extends StatefulWidget {
  final String currentId;
  const _TranslationPickerSheet({required this.currentId});

  @override
  State<_TranslationPickerSheet> createState() =>
      _TranslationPickerSheetState();
}

class _TranslationPickerSheetState extends State<_TranslationPickerSheet> {
  final TextEditingController _search = TextEditingController();
  List<TranslationEdition> _filtered = TranslationEditions.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = TranslationEditions.all
          .where(
            (e) =>
                e.language.toLowerCase().contains(q) ||
                e.translator.toLowerCase().contains(q) ||
                e.languageCode.contains(q),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Choose Translation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search language or translator…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final edition = _filtered[index];
                  final isSelected = edition.id == widget.currentId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? scheme.primary
                          : scheme.surfaceContainerHigh,
                      child: Text(
                        edition.languageCode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    title: Text(edition.language),
                    subtitle: Text(edition.translator),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: scheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(edition),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
