import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../experts/presentation/widgets/expert_pass_gate.dart';
import '../../experts/presentation/widgets/expert_portal_widgets.dart';
import '../models/course.dart';
import '../providers/my_courses_provider.dart';
import '../repositories/course_repository.dart';
import 'course_form_screen.dart';
import 'widgets/my_course_tile.dart';

/// Expert Portal "My Courses" (website: Course Studio + Manage All My
/// Courses): my published videos with views, and Add / Edit / Delete.
class MyCoursesScreen extends StatelessWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExpertPassGate(title: 'My Courses', child: _MyCoursesView());
  }
}

class _MyCoursesView extends ConsumerWidget {
  const _MyCoursesView();

  Future<void> _openForm(BuildContext context, {Course? course}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CourseFormScreen(course: course)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this course?'),
        content: Text(
          '"${course.title}" will be removed from Resources for everyone. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(myCoursesProvider.notifier).remove(course);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? 'Course deleted.')));
  }

  Future<void> _watch(BuildContext context, WidgetRef ref, Course c) async {
    final url = Uri.tryParse(c.watchUrl);
    final opened = url != null && c.watchUrl.isNotEmpty
        ? await ref.read(courseVideoLauncherProvider)(url)
        : false;
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open this video.')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCoursesProvider);
    final notifier = ref.read(myCoursesProvider.notifier);
    final firstLoad = state.isLoading && state.courses.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ExpertPortalHero(
                  title: 'Create & Manage',
                  highlight: 'Courses',
                  subtitle:
                      'Publish YouTube training videos to the KaamMilega '
                      'learning library.',
                  trailing: TextButton.icon(
                    onPressed: () => context.push('/feed'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.public_rounded, size: 16),
                    label: const Text('Public view'),
                  ),
                  bottom: _HeroStats(
                    courses: firstLoad || state.error != null
                        ? null
                        : state.total,
                    views: firstLoad || state.error != null
                        ? null
                        : state.totalViews,
                    onAdd: () => _openForm(context),
                  ),
                ),
              ),
              if (firstLoad)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverList.list(
                    children: const [
                      ShimmerBox(width: 120, height: 16),
                      SizedBox(height: 14),
                      ShimmerLoadingList(count: 4, itemHeight: 104),
                    ],
                  ),
                )
              else if (state.error != null && state.courses.isEmpty)
                // The message scrolls itself, so it gets the remaining height
                // as-is (laid out once).
                SliverFillRemaining(
                  child: NetworkStateView.fromError(
                    state.error!,
                    onRetry: notifier.refresh,
                  ),
                )
              else if (state.courses.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyCourses(onAdd: () => _openForm(context)),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      state.total == 1
                          ? 'Your published course'
                          : 'Your published courses',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandNavy,
                      ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: state.courses.length,
                  itemBuilder: (context, i) {
                    final c = state.courses[i];
                    return MyCourseTile(
                      key: ValueKey(c.id),
                      course: c,
                      onWatch: () => _watch(context, ref, c),
                      onEdit: () => _openForm(context, course: c),
                      onDelete: () => _delete(context, ref, c),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: _Footer(state: state, onLoadMore: notifier.loadMore),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Course count and total views in two glass tiles, then "Add New Course".
class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.courses,
    required this.views,
    required this.onAdd,
  });

  final int? courses;
  final int? views;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.video_library_outlined,
                label: 'Courses',
                value: courses?.toString() ?? '--',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                icon: Icons.visibility_outlined,
                label: 'Total views',
                value: views == null ? '--' : _compact(views!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Add New Course',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  static String _compact(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentBright),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.75),
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

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.ondemand_video_rounded,
              size: 34,
              color: AppColors.brandNavy,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No courses published yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first YouTube training video. It appears in Resources '
            'for everyone to learn from.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandNavy,
              side: const BorderSide(color: AppColors.brandNavy),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first course'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final MyCoursesState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Center(
          child: TextButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Could not load more. Retry'),
          ),
        ),
      );
    }
    if (state.hasMore) {
      if (!state.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ShimmerBox(width: double.infinity, height: 96, borderRadius: 18),
      );
    }
    return const SizedBox(height: 32);
  }
}
