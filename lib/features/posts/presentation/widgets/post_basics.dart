import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/models/user_profile.dart';
import '../../../home/presentation/widgets/connect_like_you_section.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../models/post.dart';

/// Avatar of a post or comment author (photo, else a coloured initial).
class PostAuthorAvatar extends StatelessWidget {
  const PostAuthorAvatar({super.key, required this.author, this.size = 44});

  final PostAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: PersonAvatar(
        size: size,
        user: UserProfile(
          id: author.id,
          mobile: '',
          name: author.name,
          profileImage: author.avatarUrl,
        ),
      ),
    );
  }
}

/// Look of each reaction (Material icons, no emoji).
abstract final class ReactionStyle {
  static IconData icon(PostReaction r) => switch (r) {
    PostReaction.like => Icons.thumb_up_alt_rounded,
    PostReaction.celebrate => Icons.celebration_rounded,
    PostReaction.support => Icons.volunteer_activism_rounded,
    PostReaction.love => Icons.favorite_rounded,
    PostReaction.insightful => Icons.lightbulb_rounded,
  };

  static Color color(PostReaction r) => switch (r) {
    PostReaction.like => AppColors.blue,
    PostReaction.celebrate => AppColors.success,
    PostReaction.support => AppColors.moduleExperts,
    PostReaction.love => AppColors.hotRose,
    PostReaction.insightful => AppColors.warning,
  };
}

/// Small round reaction icon (used in the counts summary).
class ReactionDot extends StatelessWidget {
  const ReactionDot({super.key, required this.reaction, this.size = 18});

  final PostReaction reaction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ReactionStyle.color(reaction),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Icon(
        ReactionStyle.icon(reaction),
        size: size * 0.58,
        color: AppColors.white,
      ),
    );
  }
}

/// Bottom sheet to choose a reaction. Returns the chosen one, or null when
/// dismissed.
Future<PostReaction?> showReactionPicker(
  BuildContext context, {
  PostReaction? current,
}) {
  return showModalBottomSheet<PostReaction>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'React to this post',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 8,
              children: [
                for (final r in PostReaction.values)
                  _ReactionOption(
                    reaction: r,
                    selected: r == current,
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReactionOption extends StatelessWidget {
  const _ReactionOption({
    required this.reaction,
    required this.selected,
    required this.onTap,
  });

  final PostReaction reaction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ReactionStyle.color(reaction);
    return Semantics(
      button: true,
      selected: selected,
      label: reaction.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(ReactionStyle.icon(reaction), color: color),
              ),
              const SizedBox(height: 6),
              Text(
                reaction.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder shaped like a post card.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key, this.withImage = true});

  final bool withImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ShimmerCircle(size: 44),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 140, height: 12),
                    SizedBox(height: 8),
                    ShimmerBox(width: 200, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: double.infinity, height: 10),
          const SizedBox(height: 8),
          const ShimmerBox(width: double.infinity, height: 10),
          const SizedBox(height: 8),
          const ShimmerBox(width: 180, height: 10),
          if (withImage) ...[
            const SizedBox(height: 14),
            const ShimmerBox(
              width: double.infinity,
              height: 160,
              borderRadius: 12,
            ),
          ],
        ],
      ),
    );
  }
}

/// A few skeleton cards for the first load.
class PostsSkeletonList extends StatelessWidget {
  const PostsSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      children: const [
        PostCardSkeleton(),
        PostCardSkeleton(withImage: false),
        PostCardSkeleton(),
      ],
    );
  }
}
