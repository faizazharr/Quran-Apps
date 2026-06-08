import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../sleep_timer/bloc/sleep_timer_bloc.dart';

/// Dialog for selecting a sleep timer duration.
/// Reads the app-level [SleepTimerBloc] from context — do NOT wrap this widget
/// in a new BlocProvider, as that would create an isolated BLoC disconnected
/// from the app's sleep-timer listener in [QuranPlayerApp].
class SleepTimerDialog extends StatelessWidget {
  const SleepTimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.sleepTimer),
      content: BlocBuilder<SleepTimerBloc, SleepTimerState>(
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isActive) ...[
                Text(
                  state.isEndOfSurah
                      ? l10n.sleepTimerEndOfSurah
                      : _formatRemaining(state.remaining),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.read<SleepTimerBloc>().add(
                    const SleepTimerCancelRequested(),
                  ),
                  child: Text(l10n.cancel),
                ),
              ] else ...[
                _Option(
                  label: l10n.sleepTimerMinutes(15),
                  option: SleepTimerOption.min15,
                ),
                _Option(
                  label: l10n.sleepTimerMinutes(30),
                  option: SleepTimerOption.min30,
                ),
                _Option(
                  label: l10n.sleepTimerMinutes(45),
                  option: SleepTimerOption.min45,
                ),
                _Option(
                  label: l10n.sleepTimerMinutes(60),
                  option: SleepTimerOption.min60,
                ),
                _Option(
                  label: l10n.sleepTimerEndOfSurah,
                  option: SleepTimerOption.endOfSurah,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatRemaining(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Option extends StatelessWidget {
  final String label;
  final SleepTimerOption option;

  const _Option({required this.label, required this.option});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.read<SleepTimerBloc>().add(SleepTimerStartRequested(option));
        Navigator.of(context).pop();
      },
    );
  }
}
