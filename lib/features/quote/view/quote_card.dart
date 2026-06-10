import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/surah.dart';
import '../../search/bloc/search_bloc.dart';
import '../../surah/view/surah_detail_page.dart';
import '../bloc/quote_bloc.dart';

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<QuoteBloc, QuoteState>(
      builder: (context, state) {
        if (state.status == QuoteStatus.loading) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (state.status == QuoteStatus.error) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 120,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.errorMessage ?? 'Failed to load quote of the day',
                    style: TextStyle(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final quote = state.quote;
        if (quote == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                // Navigate to the full surah detail page so the user can
                // read the surrounding context and listen to the surah.
                final surah = context
                    .read<SearchBloc>()
                    .state
                    .surahs
                    .cast<Surah?>()
                    .firstWhere(
                      (s) => s?.number == quote.surahNumber,
                      orElse: () => null,
                    );
                if (surah != null) {
                  unawaited(SurahDetailPage.show(context, surah));
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Badge Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${quote.surahEnglishName} • Ayah ${quote.ayahNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next Quote',
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () {
                            context.read<QuoteBloc>().add(
                              const QuoteRefreshRequested(),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Arabic Text
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        quote.arabicText,
                        style: const TextStyle(
                          fontFamily: 'Scheherazade New',
                          fontSize: 22,
                          height: 1.8,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Translation
                    if (quote.translation != null)
                      Text(
                        quote.translation!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Footer message & Action prompt
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: Colors.white54,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Quote of the Day',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tap to read Surah →',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
