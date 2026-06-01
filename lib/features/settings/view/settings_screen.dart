import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/app_settings.dart';
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
              _SectionHeader('Bookmarks'),
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
