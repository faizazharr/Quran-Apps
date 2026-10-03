import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/tip_bloc.dart';

/// Voluntary tip card (Google Play Billing). Unlocks nothing; hidden when
/// billing or the products are unavailable.
class SupportCard extends StatelessWidget {
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TipBloc>()..add(const TipLoadRequested()),
      child: const _SupportCardView(),
    );
  }
}

class _SupportCardView extends StatelessWidget {
  const _SupportCardView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return BlocConsumer<TipBloc, TipState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        final msg = switch (state.status) {
          TipStatus.thanks => l10n.supportThanks,
          TipStatus.failed => l10n.supportFailed,
          _ => null,
        };
        if (msg != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        if (state.products.isEmpty) return const SizedBox.shrink();
        final busy = state.status == TipStatus.purchasing;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: scheme.primaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.supportTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.supportBody,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in state.products)
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => context.read<TipBloc>().add(
                                TipPurchaseRequested(p),
                              ),
                        child: Text(p.price),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
