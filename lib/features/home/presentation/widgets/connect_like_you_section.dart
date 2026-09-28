import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/models/user_profile.dart';
import '../../../network/presentation/widgets/connect_button.dart';
import '../../../network/providers/network_provider.dart';

/// Home: "Connect Just Like You", the same people row as the website home
/// page (GET /community/users). Connect sends POST /network/connect; the
/// button state comes from GET /network/status/:id for signed-in users.
class ConnectLikeYouSection extends StatelessWidget {
  const ConnectLikeYouSection({super.key});

  @override
  Widget build(BuildContext context) {
    return PeopleRowSection(
      provider: communityUsersProvider,
      highlight: 'Connect',
      after: ' Just Like You',
      errorText: 'Could not load people right now.',
      onSeeAll: () => AuthGuard.openProtected(
        context,
        '/peer-to-peer',
        message: 'Please log in to find and connect with people.',
      ),
    );
  }
}

/// Home: "Connect With Our Experts" (GET /experts, same list as the website
/// home page). Same cards, Connect / Chat and profile page as above.
class ConnectExpertsSection extends StatelessWidget {
  const ConnectExpertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return PeopleRowSection(
      provider: featuredExpertsProvider,
      before: 'Connect With Our ',
      highlight: 'Experts',
      errorText: 'Could not load experts right now.',
      onSeeAll: () => context.push('/experts'),
    );
  }
}

/// A titled, sideways row of people cards with loading, error (Retry) and
/// empty (hidden) states.
class PeopleRowSection extends ConsumerWidget {
  const PeopleRowSection({
    super.key,
    required this.provider,
    required this.highlight,
    required this.errorText,
    required this.onSeeAll,
    this.before = '',
    this.after = '',
  });

  final FutureProvider<List<UserProfile>> provider;
  final String before;
  final String highlight;
  final String after;
  final String errorText;
  final VoidCallback onSeeAll;

  static const double cardWidth = 200;
  static const double rowHeight = 236;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(provider);

    Widget section(Widget child) => _Section(
      before: before,
      highlight: highlight,
      after: after,
      onSeeAll: onSeeAll,
      child: child,
    );

    return usersAsync.when(
      // No people to show: the section is hidden, as on the website.
      data: (users) => users.isEmpty
          ? const SizedBox.shrink()
          : section(
              SizedBox(
                height: rowHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      PersonConnectCard(user: users[index]),
                ),
              ),
            ),
      loading: () => section(
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const ShimmerBox(
              width: cardWidth,
              height: rowHeight,
              borderRadius: 16,
            ),
          ),
        ),
      ),
      // A failure is shown as a failure (with Retry), never as "no people".
      error: (_, _) => section(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.before,
    required this.highlight,
    required this.after,
    required this.onSeeAll,
    required this.child,
  });

  final String before;
  final String highlight;
  final String after;
  final VoidCallback onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (before.isNotEmpty) TextSpan(text: before),
                      TextSpan(
                        text: highlight,
                        style: const TextStyle(color: AppColors.primary),
                      ),
                      if (after.isNotEmpty) TextSpan(text: after),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// One person with Connect and Chat; tapping the card opens the person's
/// profile. Contact details (mobile, email) are never shown.
class PersonConnectCard extends ConsumerWidget {
  const PersonConnectCard({super.key, required this.user});

  final UserProfile user;

  String get _name => user.name.trim().isNotEmpty ? user.name.trim() : 'Member';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headline = user.headline.trim();
    final city = user.city.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => AuthGuard.openProtected(
          context,
          '/members/${user.id}',
          message: 'Please log in to view member profiles.',
        ),
        child: Container(
          width: PeopleRowSection.cardWidth,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: user.profileImage.isNotEmpty
                    ? NetworkImage(user.profileImage)
                    : null,
                onBackgroundImageError: user.profileImage.isNotEmpty
                    ? (_, _) {}
                    : null,
                child: user.profileImage.isEmpty
                    ? Text(
                        _name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                headline.isNotEmpty ? headline : 'KaamMilega member',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              if (city.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ConnectButton(userId: user.id, name: _name),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => chatWithMember(
                        context,
                        ref,
                        userId: user.id,
                        name: _name,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Semantics(
                        label: 'Chat with $_name',
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
