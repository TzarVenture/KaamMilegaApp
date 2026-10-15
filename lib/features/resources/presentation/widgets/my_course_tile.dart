import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/course.dart';

enum _CourseAction { watch, edit, delete }

/// One of my courses in "My Courses": thumbnail with play and duration,
/// category, title, views and release date, and a menu with Watch, Edit
/// and Delete.
class MyCourseTile extends StatelessWidget {
  const MyCourseTile({
    super.key,
    required this.course,
    required this.onWatch,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final VoidCallback onWatch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(course: course, onTap: onWatch),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                course.category.isEmpty
                                    ? 'General'
                                    : course.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            height: 24,
                            child: PopupMenuButton<_CourseAction>(
                              tooltip: 'Course options',
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: AppColors.textSecondary,
                              ),
                              color: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              position: PopupMenuPosition.under,
                              onSelected: (a) {
                                switch (a) {
                                  case _CourseAction.watch:
                                    onWatch();
                                  case _CourseAction.edit:
                                    onEdit();
                                  case _CourseAction.delete:
                                    onDelete();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: _CourseAction.watch,
                                  child: _MenuRow(
                                    icon: Icons.play_circle_outline_rounded,
                                    text: 'Watch on YouTube',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _CourseAction.edit,
                                  child: _MenuRow(
                                    icon: Icons.edit_outlined,
                                    text: 'Edit details',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _CourseAction.delete,
                                  child: _MenuRow(
                                    icon: Icons.delete_outline_rounded,
                                    text: 'Delete course',
                                    danger: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _Meta(
                            icon: Icons.visibility_outlined,
                            text: course.viewersLabel,
                            strong: true,
                          ),
                          _Meta(
                            icon: Icons.calendar_today_outlined,
                            text: course.releasedLabel,
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const width = 124.0;
    Widget placeholder() => const Center(
      child: Icon(
        Icons.ondemand_video_rounded,
        color: AppColors.white,
        size: 28,
      ),
    );

    return Semantics(
      button: true,
      label: 'Watch ${course.title} on YouTube',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: width,
            height: width * 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.brandNavy,
                  child: course.thumbnail.isEmpty
                      ? placeholder()
                      : Image(
                          image: ResizeImage.resizeIfNeeded(
                            (width * dpr).round(),
                            null,
                            NetworkImage(course.thumbnail),
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder(),
                        ),
                ),
                const ColoredBox(color: Color(0x26000000)),
                Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 20,
                      color: AppColors.brandNavy,
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: width - 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      course.durationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
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
        Icon(
          icon,
          size: 13,
          color: strong ? AppColors.blue : AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong ? AppColors.brandNavy : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text, this.danger = false});

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 19, color: danger ? AppColors.error : AppColors.blue),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
