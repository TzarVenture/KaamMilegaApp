import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../models/course.dart';
import '../providers/courses_provider.dart';
import 'widgets/course_youtube_player.dart';

/// Plays a course video inside the app (YouTube's embedded player), with
/// the course details below and "Watch on YouTube" to open it in the
/// YouTube app instead. The view is counted by the page that opens this.
class CoursePlayerScreen extends ConsumerWidget {
  const CoursePlayerScreen({
    super.key,
    required this.course,
    required this.onOpenYouTube,
    this.onOpenExpert,
  });

  final Course course;
  final VoidCallback onOpenYouTube;
  final VoidCallback? onOpenExpert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fresh view count from the Resources list (it updates after the
    // server answers).
    final live =
        ref.watch(
          coursesProvider.select(
            (s) => s.courses.where((c) => c.id == course.id).firstOrNull,
          ),
        ) ??
        course;
    final videoId = live.youtubeVideoId.isNotEmpty
        ? live.youtubeVideoId
        : Course.extractVideoId(live.watchUrl);
    final player = ref.watch(courseVideoPlayerProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            ColoredBox(
              color: AppColors.black,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              live.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: videoId == null
                          ? const _NoPlayer()
                          : player(videoId),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  if (live.category.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          live.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    live.title,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _Meta(
                        icon: Icons.visibility_outlined,
                        text: live.viewersLabel,
                        strong: true,
                      ),
                      _Meta(
                        icon: Icons.schedule_rounded,
                        text: live.durationLabel,
                      ),
                      _Meta(
                        icon: Icons.calendar_today_outlined,
                        text: live.releasedLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _YouTubeButton(onTap: onOpenYouTube),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 14),
                  _ExpertTile(course: live, onTap: onOpenExpert),
                  if (live.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'About this video',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      live.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlayer extends StatelessWidget {
  const _NoPlayer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This video cannot be played here. Use Watch on YouTube below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.white, fontSize: 13.5),
        ),
      ),
    );
  }
}

/// Full-width "Watch on YouTube" (opens the YouTube app or browser).
class _YouTubeButton extends StatelessWidget {
  const _YouTubeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
          backgroundColor: AppColors.error.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.smart_display_rounded, size: 22),
        label: const Text(
          'Watch on YouTube',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ExpertTile extends StatelessWidget {
  const _ExpertTile({required this.course, required this.onTap});

  final Course course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = course.expertAvatar;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight,
                foregroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                onForegroundImageError: avatar.isEmpty ? null : (_, _) {},
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.expertLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Course expert',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.blue),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong ? AppColors.brandNavy : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
