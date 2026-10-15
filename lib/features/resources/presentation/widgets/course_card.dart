import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../home/presentation/widgets/home_section_header.dart';
import '../../models/course.dart';

/// One learning video, laid out for phones: 16:9 thumbnail (category badge,
/// play button, duration), title, short description, then duration,
/// expert, viewers and release date (same details as the website card).
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.onWatch,
    required this.onOpenExpert,
    this.onOpenYouTube,
    this.isOwner = false,
  });

  final Course course;

  /// Plays the video in the app (card and play button).
  final VoidCallback onWatch;

  /// Small "YouTube" button on the picture: opens the YouTube app.
  final VoidCallback? onOpenYouTube;
  final VoidCallback? onOpenExpert;

  /// The signed-in member uploaded this video (their views are not counted).
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: HomeCardShadow(
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(HomeCard.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onWatch,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Thumbnail(
                  course: course,
                  onWatch: onWatch,
                  onOpenYouTube: onOpenYouTube,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (course.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          course.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 10),
                      _ExpertRow(
                        course: course,
                        onTap: onOpenExpert,
                        isOwner: isOwner,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _Meta(
                            icon: Icons.visibility_outlined,
                            text: course.viewersLabel,
                            strong: true,
                          ),
                          _Meta(
                            icon: Icons.schedule_rounded,
                            text: course.durationLabel,
                          ),
                          _Meta(
                            icon: Icons.calendar_today_outlined,
                            text: course.releasedLabel,
                            muted: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.course,
    required this.onWatch,
    this.onOpenYouTube,
  });

  final Course course;
  final VoidCallback onWatch;
  final VoidCallback? onOpenYouTube;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final cacheWidth = (width * dpr).round().clamp(320, 1280);

    Widget fallback() {
      final alt = course.fallbackThumbnail;
      if (alt.isEmpty || alt == course.thumbnail) {
        return const Center(
          child: Icon(
            Icons.ondemand_video_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
        );
      }
      return Image.network(
        alt,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.ondemand_video_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Play ${course.title}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onWatch,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppColors.brandNavy,
                child: course.thumbnail.isEmpty
                    ? fallback()
                    : Image(
                        image: ResizeImage.resizeIfNeeded(
                          cacheWidth,
                          null,
                          NetworkImage(course.thumbnail),
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback(),
                      ),
              ),
              // Soft shade so the badges and play button read on any image.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x14000000), Color(0x40000000)],
                  ),
                ),
              ),
              if (course.category.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: width * 0.6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.brandNavy,
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Text(
                      course.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: AppColors.brandNavy,
                  ),
                ),
              ),
              if (onOpenYouTube != null)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: _YouTubePill(onTap: onOpenYouTube!),
                ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: AppColors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        course.durationLabel,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small white "YouTube" pill on the picture: opens the video in the
/// YouTube app (the rest of the picture plays it in the app).
class _YouTubePill extends StatelessWidget {
  const _YouTubePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Watch on YouTube',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: const StadiumBorder(),
        elevation: 2,
        shadowColor: AppColors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_display_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
                SizedBox(width: 4),
                Text(
                  'YouTube',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpertRow extends StatelessWidget {
  const _ExpertRow({
    required this.course,
    required this.onTap,
    required this.isOwner,
  });

  final Course course;
  final VoidCallback? onTap;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final avatar = course.expertAvatar;
    return Row(
      children: [
        Flexible(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.primaryLight,
                    foregroundImage: avatar.isEmpty
                        ? null
                        : NetworkImage(avatar),
                    onForegroundImageError: avatar.isEmpty ? null : (_, _) {},
                    child: const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: AppColors.brandNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'By ${course.expertLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isOwner) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Your video',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accentText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.strong = false,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: muted ? AppColors.textMuted : AppColors.blue,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong
                  ? AppColors.brandNavy
                  : (muted ? AppColors.textMuted : AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}
