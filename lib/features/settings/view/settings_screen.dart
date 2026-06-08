import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/translation_edition.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../bookmark/bloc/bookmark_bloc.dart';
import '../../player/bloc/player_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/sleep_timer_dialog.dart';

/// Full-page settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = state.settings;

          return ListView(
            children: [
              // --- Theme ---
              _SectionHeader(l10n.darkMode),
              RadioGroup<AppThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (v) {
                  if (v != null) {
                    context.read<SettingsBloc>().add(SettingsThemeChanged(v));
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<AppThemeMode>(
                      title: Text(l10n.themeSystem),
                      value: AppThemeMode.system,
                    ),
                    RadioListTile<AppThemeMode>(
                      title: Text(l10n.themeLight),
                      value: AppThemeMode.light,
                    ),
                    RadioListTile<AppThemeMode>(
                      title: Text(l10n.themeDark),
                      value: AppThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const Divider(),

              // --- Language ---
              _SectionHeader(l10n.language),
              RadioGroup<String?>(
                groupValue: settings.localeTag,
                onChanged: (v) =>
                    context.read<SettingsBloc>().add(SettingsLocaleChanged(v)),
                child: const Column(
                  children: [
                    RadioListTile<String?>(
                      title: Text('Follow device'),
                      value: null,
                    ),
                    RadioListTile<String?>(title: Text('English'), value: 'en'),
                    RadioListTile<String?>(
                      title: Text('Indonesia'),
                      value: 'id',
                    ),
                  ],
                ),
              ),
              const Divider(),

              // --- Translation ---
              const _SectionHeader('Quran Translation'),
              _TranslationPicker(current: settings.translationEditionId),
              const Divider(),

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
                      BlocProvider.value(value: context.read<PlayerBloc>()),
                    ],
                    child: const SleepTimerDialog(),
                  ),
                ),
              ),
              const Divider(),

              // --- Bookmarks ---
              const _SectionHeader('Bookmarks'),
              BlocBuilder<BookmarkBloc, BookmarkState>(
                builder: (context, bState) {
                  if (bState.bookmarks.isEmpty) {
                    return const ListTile(title: Text('No bookmarks saved.'));
                  }
                  return Column(
                    children: bState.bookmarks.map((b) {
                      return ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text('Surah ${b.surahNumber}'),
                        subtitle: Text(b.editionId),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => context.read<BookmarkBloc>().add(
                            BookmarkDeleteRequested(b.id!),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
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
