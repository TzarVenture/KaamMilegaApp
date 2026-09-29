import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/models/user_profile.dart';
import '../../home/presentation/widgets/connect_like_you_section.dart';
import '../../network/providers/network_provider.dart';

/// "Who viewed your profile" (GET /user/viewers): the members who most
/// recently opened your profile, newest first (the server keeps up to 20).
/// Tapping a person opens their profile.
class ProfileViewersScreen extends ConsumerWidget {
  const ProfileViewersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewers = ref.watch(profileViewersProvider);
    final list = viewers.asData?.value ?? const <UserProfile>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Who viewed your profile',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            ref.invalidate(profileViewersProvider);
            await ref.read(profileViewersProvider.future);
          } catch (_) {
            // Shown on the page with a Retry button.
          }
        },
        child: NetworkStateView(
          isLoading: viewers.isLoading && !viewers.hasValue,
          errorMessage: viewers.hasError && !viewers.hasValue
              ? 'Could not load who viewed your profile.'
              : null,
          onRetry: () => ref.invalidate(profileViewersProvider),
          isEmpty: viewers.hasValue && list.isEmpty,
          emptyTitle: 'No profile views yet',
          emptyMessage:
              'When other members open your profile, they will appear here.',
          loadingWidget: const ShimmerLoadingList(count: 5, itemHeight: 72),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Text(
                  'Members who recently opened your profile. Only you can '
                  'see this list.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                );
              }
              return _ViewerTile(user: list[index - 1]);
            },
          ),
        ),
      ),
    );
  }
}

class _ViewerTile extends StatelessWidget {
  const _ViewerTile({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Member';
    final subtitle = [
      user.headline.trim(),
      user.city.trim(),
    ].where((v) => v.isNotEmpty).join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/members/${user.id}'),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              PersonAvatar(user: user, size: 46),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
