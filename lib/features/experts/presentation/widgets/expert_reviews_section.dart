import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../models/expert_review.dart';
import '../../repositories/expert_repository.dart';

const Color _star = Color(0xFFF59E0B);

/// "Candidate Ratings & Reviews" on an Expert's page: average, a bar per
/// star and the newest reviews (GET /mentorships/expert/:id/reviews).
/// The backend only accepts a review from the mentee of a completed
/// session.
class ExpertReviewsSection extends ConsumerWidget {
  const ExpertReviewsSection({
    super.key,
    required this.expertId,
    this.expertName = '',
  });

  final String expertId;

  /// Shown in the empty state ("Be the first to book a session with
  /// [expertName] ...").
  final String expertName;

  /// Reviews shown on the page; the rest open in a sheet.
  static const int previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expertId.trim().isEmpty) return const SizedBox.shrink();
    final async = ref.watch(expertReviewsProvider(expertId));
    final data = async.asData?.value;
    return _Card(
      average: data == null || data.isEmpty ? null : data,
      child: async.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: double.infinity, height: 84, borderRadius: 12),
            SizedBox(height: 14),
            ShimmerBox(width: double.infinity, height: 72, borderRadius: 12),
          ],
        ),
        // Not deployed on this server yet: say so, not "no reviews".
        error: (e, _) => e is AppNotFoundException
            ? const _Note('Reviews are not available yet.')
            : Row(
                children: [
                  const Expanded(
                    child: _Note('Could not load reviews right now.'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(expertReviewsProvider(expertId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
        data: (data) {
          if (data.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VerifiedNote(),
                const SizedBox(height: 14),
                _EmptyReviews(expertName: expertName),
              ],
            );
          }
          final shown = data.reviews.take(previewCount).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Summary(data: data),
              const SizedBox(height: 12),
              const _VerifiedNote(),
              for (final r in shown) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                ReviewTile(review: r),
              ],
              if (data.reviews.length > shown.length) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _showAll(context, data),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'See all ${data.reviews.length} reviews',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showAll(BuildContext context, ExpertReviews data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView.separated(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: data.reviews.length + 1,
            separatorBuilder: (_, i) => i == 0
                ? const SizedBox(height: 8)
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: AppColors.borderLight),
                  ),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetDragHandle(),
                    Text(
                      '${data.totalReviews} '
                      '${data.totalReviews == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                );
              }
              return ReviewTile(review: data.reviews[i - 1]);
            },
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.average});

  final Widget child;

  /// Loaded reviews (not empty): the score badge in the header.
  final ExpertReviews? average;

  @override
  Widget build(BuildContext context) {
    final avg = average;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.star_rounded, size: 22, color: _star),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidate Ratings & Reviews',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Verified feedback from candidates who completed 1-on-1 '
                      'mentorship sessions',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (avg != null) ...[
                const SizedBox(width: 8),
                _ScoreBadge(data: avg),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
          child,
        ],
      ),
    );
  }
}

/// Small amber badge: average and stars.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.data});

  final ExpertReviews data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.topMatchCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.topMatchBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.averageRating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 18,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: AppColors.accentText,
            ),
          ),
          const SizedBox(height: 2),
          Stars(rating: data.averageRating, size: 11),
        ],
      ),
    );
  }
}

/// What makes a review trustworthy (enforced by the backend: only the
/// mentee of a completed session can review it).
class _VerifiedNote extends StatelessWidget {
  const _VerifiedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: AppColors.success,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Candidate Feedback',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Only candidates who booked and completed a 1-on-1 session '
                  'with this mentor can leave a review.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({required this.expertName});

  final String expertName;

  @override
  Widget build(BuildContext context) {
    final name = expertName.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.topMatchCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.topMatchBorder),
            ),
            child: const Icon(Icons.star_rounded, color: _star, size: 26),
          ),
          const SizedBox(height: 10),
          const Text(
            'No Reviews Yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Be the first to book a session with '),
                TextSpan(
                  text: name.isNotEmpty ? name : 'this mentor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(
                  text: ' and leave your feedback after it is completed.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
  }
}

/// Big average with stars on the left, one bar per star on the right.
class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final ExpertReviews data;

  @override
  Widget build(BuildContext context) {
    final count = data.totalReviews;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                data.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Stars(rating: data.averageRating, size: 14),
              const SizedBox(height: 4),
              Text(
                '$count ${count == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (var s = 5; s >= 1; s--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text(
                            '$s',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(Icons.star_rounded, size: 12, color: _star),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: data.share(s),
                              minHeight: 7,
                              backgroundColor: AppColors.borderLight,
                              valueColor: const AlwaysStoppedAnimation(_star),
                              semanticsLabel: '$s star reviews',
                              semanticsValue: '${data.starCounts[s - 1]}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${(data.share(s) * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of five stars filled up to [rating] (half stars shown as half).
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                rating >= i
                    ? Icons.star_rounded
                    : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
                size: size,
                color: _star,
              ),
          ],
        ),
      ),
    );
  }
}

/// One review: who wrote it (verified mentee), stars, date, the session it
/// was for and the text (long text folds with "Read more").
class ReviewTile extends StatefulWidget {
  const ReviewTile({super.key, required this.review});

  final ExpertReview review;

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  static const int _foldAt = 180;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final name = r.displayName;
    final date = r.createdAt == null
        ? ''
        : DateFormat('d MMM yyyy').format(r.createdAt!);
    final long = r.review.length > _foldAt;
    final text = long && !_expanded
        ? '${r.review.substring(0, _foldAt).trimRight()}...'
        : r.review;
    final hasPhoto = r.menteeAvatar.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.moduleExpertsLight,
              foregroundImage: hasPhoto ? NetworkImage(r.menteeAvatar) : null,
              onForegroundImageError: hasPhoto ? (_, _) {} : null,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.moduleExperts,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (r.menteeHeadline.isNotEmpty)
                    Text(
                      r.menteeHeadline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Stars(rating: r.rating, size: 15),
            if (date.isNotEmpty)
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 12,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Verified session',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (r.sessionTitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            r.sessionTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.moduleExperts,
            ),
          ),
        ],
        if (r.review.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                foregroundColor: AppColors.primary,
              ),
              child: Text(_expanded ? 'Show less' : 'Read more'),
            ),
        ],
      ],
    );
  }
}
