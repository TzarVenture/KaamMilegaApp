import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/models/user_profile.dart';
import '../../../network/presentation/widgets/connect_button.dart';
import '../../../network/providers/network_provider.dart';
import '../../../network/services/impression_tracker.dart';
import 'home_section_header.dart';

/// Home: "Connect Just Like You", the same people as the website home page
/// (GET /community/users). Connect sends POST /network/connect; the button
/// state comes from GET /network/status/:id for signed-in users.
class ConnectLikeYouSection extends StatelessWidget {
  const ConnectLikeYouSection({super.key});

  @override
  Widget build(BuildContext context) {
    return PeopleRowSection(
      provider: communityUsersProvider,
      highlight: 'Connect',
      after: ' Just Like You',
      subtitle: 'People on KaamMilega you may know',
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
/// home page). Same rows, Connect / Chat and profile page as above.
class ConnectExpertsSection extends StatelessWidget {
  const ConnectExpertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return PeopleRowSection(
      provider: featuredExpertsProvider,
      before: 'Connect With Our ',
      highlight: 'Experts',
      subtitle: 'Get advice from people with experience',
      errorText: 'Could not load experts right now.',
      isExperts: true,
      onSeeAll: () => context.push('/experts'),
    );
  }
}

/// A titled, sideways row of compact people cards, with loading, error
/// (Retry) and empty (hidden) states.
class PeopleRowSection extends ConsumerWidget {
  const PeopleRowSection({
    super.key,
    required this.provider,
    required this.highlight,
    required this.errorText,
    required this.onSeeAll,
    this.before = '',
    this.after = '',
    this.subtitle = '',
    this.isExperts = false,
  });

  final FutureProvider<List<UserProfile>> provider;
  final String before;
  final String highlight;
  final String after;
  final String subtitle;
  final String errorText;
  final VoidCallback onSeeAll;
  final bool isExperts;

  static const double cardWidth = 150;

  /// Card height grows with the phone's text size so nothing is cut off.
  static double rowHeight(BuildContext context) {
    final t = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    // A few pixels of spare room for fonts with taller line heights
    // Card: photo, name, one line of details, divider, one 38px button.
    return 136 + 56 * t.toDouble();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(provider);
    final height = rowHeight(context);

    Widget section(Widget child) => _Section(
      subtitle: subtitle,
      before: before,
      highlight: highlight,
      after: after,
      onSeeAll: onSeeAll,
      child: child,
    );

    Widget row({required int count, required IndexedWidgetBuilder builder}) =>
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: builder,
          ),
        );

    return usersAsync.when(
      // No people to show: the section is hidden, as on the website.
      data: (users) => users.isEmpty
          ? const SizedBox.shrink()
          : section(
              row(
                count: users.length,
                builder: (context, index) =>
                    PersonConnectCard(user: users[index], isExpert: isExperts),
              ),
            ),
      loading: () => section(
        row(
          count: 3,
          builder: (_, _) =>
              ShimmerBox(width: cardWidth, height: height, borderRadius: 16),
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
    required this.subtitle,
    required this.onSeeAll,
    required this.child,
  });

  final String before;
  final String highlight;
  final String after;
  final String subtitle;
  final VoidCallback onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: '$before$highlight$after',
          subtitle: subtitle,
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        child,
      ],
    );
  }
}

/// One person as a compact card: photo or coloured initial, name,
/// headline and city, Connect and Chat. Tapping the card opens the
/// person's profile. Contact details (mobile, email) are never shown.
class PersonConnectCard extends ConsumerWidget {
  const PersonConnectCard({
    super.key,
    required this.user,
    this.isExpert = false,
  });

  final UserProfile user;
  final bool isExpert;

  String get _name => user.name.trim().isNotEmpty ? user.name.trim() : 'Member';

  /// Headline and city when given; no filler text otherwise.
  String get _subtitle => [
    user.headline.trim(),
    user.city.trim(),
  ].where((v) => v.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _subtitle;
    final card = SizedBox(
      width: PeopleRowSection.cardWidth,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => AuthGuard.openProtected(
            context,
            '/members/${user.id}',
            message: 'Please log in to view member profiles.',
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                  child: Column(
                    children: [
                      PersonAvatar(user: user, size: 52),
                      const SizedBox(height: 8),
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      const Divider(height: 14, color: AppColors.border),
                      // One action: Connect, then Pending, then Message
                      // once the request is accepted (as on the website).
                      SizedBox(
                        width: double.infinity,
                        child: ConnectButton(
                          userId: user.id,
                          name: _name,
                          height: 38,
                          fontSize: 13,
                          messageWhenConnected: true,
                          showIcon: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExpert)
                  const Positioned(top: 8, right: 8, child: _ExpertTag()),
              ],
            ),
          ),
        ),
      ),
    );
    // Seen cards count as "Post impressions" for that member
    return ImpressionBeacon(authorId: user.id, child: card);
  }
}

/// Profile photo, or the first letter on a soft brand colour that stays the
/// same for each person.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.user, this.size = 44});

  final UserProfile user;
  final double size;

  static const _palette = [
    AppColors.blue,
    AppColors.moduleSkills,
    AppColors.moduleExperts,
    AppColors.moduleServices,
    AppColors.moduleP2P,
    AppColors.moduleEvents,
    AppColors.accent,
  ];

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim();
    final key = user.id.isNotEmpty ? user.id : name;
    final color =
        _palette[key.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    final hasPhoto = user.profileImage.isNotEmpty;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.14),
      foregroundImage: hasPhoto ? NetworkImage(user.profileImage) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ExpertTag extends StatelessWidget {
  const _ExpertTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.moduleExpertsLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Expert',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.moduleExperts,
        ),
      ),
    );
  }
}
