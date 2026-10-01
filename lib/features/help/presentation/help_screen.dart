import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../repositories/help_repository.dart';

/// Help & FAQ: the questions and answers the KaamMilega team publishes
/// (the same list as the website's home page).
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(faqProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: async.when(
        loading: () => const ShimmerLoadingList(count: 6, itemHeight: 64),
        error: (e, _) => NetworkStateView.fromError(
          e,
          onRetry: () => ref.invalidate(faqProvider),
        ),
        data: (faqs) {
          final q = _query.trim().toLowerCase();
          final shown = q.isEmpty
              ? faqs
              : faqs
                    .where(
                      (f) =>
                          f.question.toLowerCase().contains(q) ||
                          f.answer.toLowerCase().contains(q),
                    )
                    .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(faqProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                if (faqs.length > 5) ...[
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search questions',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (faqs.isEmpty)
                  const _Message(
                    'No questions have been published yet. Please check back '
                    'later.',
                  )
                else if (shown.isEmpty)
                  const _Message('No question matches your search.')
                else
                  for (final f in shown) _FaqCard(item: f),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final FaqItem item;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated Container) so the tile's ink shows.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // No divider lines inside the card when it opens
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            iconColor: AppColors.brandNavy,
            title: Text(
              item.question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            children: [
              Text(
                item.answer,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
    );
  }
}
