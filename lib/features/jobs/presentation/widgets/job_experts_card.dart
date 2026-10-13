import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../home/presentation/widgets/connect_like_you_section.dart';
import '../../../home/presentation/widgets/home_section_header.dart';
import '../../../network/providers/network_provider.dart';
import '../../models/job.dart';
import '../job_links.dart';
import 'job_recruiter_card.dart' show JobSectionTitle;

/// Job page: "Experts who can help". Real experts (GET /experts) ordered by
/// how well they fit this job, as swipeable cards with Connect. Hidden when
/// there are no experts; a failure shows Retry, never an empty list.
class JobExpertsCard extends ConsumerWidget {
  const JobExpertsCard({super.key, required this.job});

  final Job job;

  static const int maxShown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allExpertsProvider);
    final height = PeopleRowSection.rowHeight(context);

    Widget frame(Widget child) => Container(
      padding: const EdgeInsets.only(top: 18, bottom: 16),
      decoration: HomeCard.decoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: JobSectionTitle(
              icon: Icons.workspace_premium_outlined,
              title: 'Experts who can help',
              subtitle: 'Get interview and career advice',
              trailing: TextButton(
                onPressed: () => context.push('/experts'),
                child: const Text('See all'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );

    return async.when(
      data: (experts) {
        if (experts.isEmpty) return const SizedBox.shrink();
        final ranked = rankExpertsForJob(experts, job).take(maxShown).toList();
        return frame(
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: ranked.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) =>
                  PersonConnectCard(user: ranked[i], isExpert: true),
            ),
          ),
        );
      },
      loading: () => frame(
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, _) => ShimmerBox(
              width: PeopleRowSection.cardWidth,
              height: height,
              borderRadius: 16,
            ),
          ),
        ),
      ),
      error: (_, _) => frame(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load experts right now.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(allExpertsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
