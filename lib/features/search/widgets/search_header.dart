import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Gradient hero header with search field.
///
/// Set [compact] to use a single-row variant — used when vertical space is
/// scarce (phone in landscape).
class SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool compact;

  /// Optional widget rendered immediately under the search field (e.g. the
  /// "continue listening" chip).
  final Widget? trailing;

  /// Optional widget placed at the far right of the logo/title row (e.g. the
  /// settings icon button).
  final Widget? actions;

  const SearchHeader({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.compact = false,
    this.trailing,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        topInset + (compact ? 10 : 16),
        20,
        compact ? 14 : 22,
      ),
      child: compact
          ? _CompactRow(
              controller: controller,
              onChanged: onChanged,
              onClear: onClear,
              scheme: scheme,
              trailing: trailing,
              actions: actions,
            )
          : _StackedHero(
              controller: controller,
              onChanged: onChanged,
              onClear: onClear,
              scheme: scheme,
              trailing: trailing,
              actions: actions,
            ),
    );
  }
}

class _StackedHero extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ColorScheme scheme;
  final Widget? trailing;
  final Widget? actions;

  const _StackedHero({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.scheme,
    this.trailing,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Logo(),
            const SizedBox(width: 12),
            const Expanded(child: _Title()),
            ?actions,
          ],
        ),
        const SizedBox(height: 18),
        _SearchField(
          controller: controller,
          onChanged: onChanged,
          onClear: onClear,
          scheme: scheme,
        ),
        if (trailing != null) ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: trailing!),
        ],
      ],
    );
  }
}

class _CompactRow extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ColorScheme scheme;
  final Widget? trailing;
  final Widget? actions;

  const _CompactRow({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.scheme,
    this.trailing,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Logo(),
            const SizedBox(width: 12),
            Expanded(
              child: _SearchField(
                controller: controller,
                onChanged: onChanged,
                onClear: onClear,
                scheme: scheme,
              ),
            ),
            ?actions,
          ],
        ),
        if (trailing != null) ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: trailing!),
        ],
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/images/logo.png',
        width: 42,
        height: 42,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quran Player',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        Text(
          'Listen to your favourite reciters',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ColorScheme scheme;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).searchHint,
          prefixIcon: Icon(Icons.search, color: scheme.primary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              );
            },
          ),
        ),
      ),
    );
  }
}
