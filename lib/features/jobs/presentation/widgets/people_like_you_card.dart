import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/models/user_profile.dart';
import '../../../home/presentation/widgets/connect_like_you_section.dart';
import '../../../network/presentation/widgets/connect_button.dart';
import '../../../network/providers/network_provider.dart';
import '../../../network/services/impression_tracker.dart';
import '../../models/job.dart';

/// A member suggested on a job page, with why they were picked (empty when
/// nothing matched and they are shown in the server's order).
typedef PersonLikeYou = ({UserProfile user, String match});

/// Picks up to [count] members for [job] from [people]: members sharing
/// the job's skills first, then a similar role in their headline, then the
/// same city. Ties keep the server's order. Pure, so it is easy to test.
List<PersonLikeYou> rankPeopleLikeYou(
  List<UserProfile> people,
  Job job, {
  int count = 3,
}) {
  String norm(String s) => s.trim().toLowerCase();
  final jobSkills = job.requirements.map(norm).where((s) => s.isNotEmpty);
  final skillSet = jobSkills.toSet();
  final titleWords = norm(job.title)
      .split(RegExp(r'[^a-z0-9+#]+'))
      .where((w) => w.length >= 3)
      .toSet();
  final city = norm(job.cityName);
  final hasCity = city.isNotEmpty && city != 'all india';

  final scored = <({int score, int index, PersonLikeYou person})>[];
  for (var i = 0; i < people.length; i++) {
    final user = people[i];
    final skills = user.skills.map(norm).where(skillSet.contains).length;
    final headline = norm(user.headline);
    final role =
        headline.isNotEmpty && titleWords.any((w) => headline.contains(w));
    final sameCity = hasCity && norm(user.city) == city;
    final match = skills > 0
        ? 'Similar skills'
        : role
        ? 'Similar role'
        : sameCity
        ? 'Same city'
        : '';
    scored.add((
      score: skills * 3 + (role ? 2 : 0) + (sameCity ? 1 : 0),
      index: i,
      person: (user: user, match: match),
    ));
  }
  scored.sort(
    (a, b) => a.score != b.score
        ? b.score.compareTo(a.score)
        : a.index.compareTo(b.index),
  );
  return scored.take(count).map((s) => s.person).toList();
}

/// Job page: "People Like You". Real members from GET /community/users
/// (the same public list as the home screen, so no extra request when it
/// is already loaded), ordered by how closely they match this job.
/// Chat and Connect ask guests to log in first. Hidden when the server
/// returns no members; a failure shows a Retry, never an empty list.
class PeopleLikeYouCard extends ConsumerWidget {
  const PeopleLikeYouCard({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(communityUsersProvider);

    return async.when(
      data: (users) {
        final people = rankPeopleLikeYou(users, job);
        if (people.isEmpty) return const SizedBox.shrink();
        return _Frame(
          footer: TextButton(
            onPressed: () => AuthGuard.openProtected(
              context,
              '/peer-to-peer',
              message: 'Please log in to find and connect with people.',
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'SHOW ALL MEMBERS',
              style: TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          children: [
            for (var i = 0; i < people.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
              _PersonRow(person: people[i]),
            ],
          ],
        );
      },
      loading: () => _Frame(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            const Row(
              children: [
                ShimmerBox(width: 52, height: 52, borderRadius: 26),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 44,
                    borderRadius: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(
              width: double.infinity,
              height: 40,
              borderRadius: 12,
            ),
          ],
        ],
      ),
      // A failure is shown as a failure (with Retry), never as "no people".
      error: (_, _) => _Frame(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load people right now.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(communityUsersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White rounded card with the "People Like You" title, as the other
/// sections of the job page.
class _Frame extends StatelessWidget {
  const _Frame({required this.children, this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, footer == null ? 20 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'People '),
                TextSpan(
                  text: 'Like You',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Members on KaamMilega you may want to connect with',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ...children,
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

class _PersonRow extends ConsumerWidget {
  const _PersonRow({required this.person});

  final PersonLikeYou person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = person.user;
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Member';
    final headline = user.headline.trim();
    final city = user.city.trim();

    void openProfile() => AuthGuard.openProtected(
      context,
      '/members/${user.id}',
      message: 'Please log in to view member profiles.',
    );

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: openProfile,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                PersonAvatar(user: user, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          headline.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (city.isNotEmpty || person.match.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (city.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      city,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (person.match.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  person.match,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      chatWithMember(context, ref, userId: user.id, name: name),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text(
                    'Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ConnectButton(
                userId: user.id,
                name: name,
                height: 40,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
    // Seen rows count as profile impressions, as on the home screen.
    return ImpressionBeacon(authorId: user.id, child: row);
  }
}
