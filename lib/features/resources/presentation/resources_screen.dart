import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/course.dart';
import '../providers/courses_provider.dart';
import '../repositories/course_repository.dart';
import 'course_player_screen.dart';
import 'widgets/course_card.dart';

/// Resources: "Learn With Kaammilega" learning videos from the server
/// (GET /courses), with search, paging, pull to refresh and real view
/// counts (POST /courses/:id/view when a video is opened). Videos open in
/// the YouTube app (or the browser), as on the website.
class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // show / hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) ref.read(coursesProvider.notifier).search(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(coursesProvider.notifier).search('');
  }

  /// Plays the video inside the app (website: opening a video counts one
  /// view). Videos without a YouTube id open in YouTube instead.
  void _watch(Course course) {
    final hasId =
        course.youtubeVideoId.isNotEmpty ||
        Course.extractVideoId(course.watchUrl) != null;
    if (!hasId) {
      _openYouTube(course);
      return;
    }
    // Count the view (as the website does) while the video opens.
    unawaited(ref.read(coursesProvider.notifier).recordView(course));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePlayerScreen(
          course: course,
          onOpenYouTube: () => _openYouTube(course, countView: false),
          onOpenExpert: course.expertId.isEmpty
              ? null
              : () => _openExpert(course),
        ),
      ),
    );
  }

  /// Opens the video in the YouTube app (or the browser). From the card
  /// this counts a view; from the in-app player it was already counted.
  Future<void> _openYouTube(Course course, {bool countView = true}) async {
    final url = Uri.tryParse(course.watchUrl);
    final messenger = ScaffoldMessenger.of(context);
    if (url == null || course.watchUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This video is not available.')),
      );
      return;
    }
    if (countView) {
      unawaited(ref.read(coursesProvider.notifier).recordView(course));
    }
    var opened = false;
    try {
      opened = await ref.read(courseVideoLauncherProvider)(url);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the video.')),
        );
    }
  }

  void _openExpert(Course course) {
    if (course.expertId.isEmpty) return;
    AuthGuard.openProtected(
      context,
      '/members/${course.expertId}',
      message: 'Please log in to view the expert profile.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coursesProvider);
    final notifier = ref.read(coursesProvider.notifier);
    final courses = state.courses;
    final firstError = courses.isEmpty ? state.error : null;
    final searching = state.query.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.brandOrange,
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onClearSearch: _clearSearch,
                ),
              ),
              if (state.isLoading && courses.isEmpty)
                SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (_, _) => const _CourseSkeleton(),
                )
              else if (firstError != null)
                // The message scrolls itself, so it gets the remaining height
                // as-is (laid out once).
                SliverFillRemaining(
                  child: NetworkStateView(
                    isOffline: firstError is AppNetworkException,
                    errorMessage: firstError is AppException
                        ? firstError.message
                        : 'Could not load courses. Please try again.',
                    onRetry: notifier.refresh,
                    child: const SizedBox.shrink(),
                  ),
                )
              else if (courses.isEmpty)
                // The message scrolls itself, so it gets the remaining height
                // as-is (laid out once).
                SliverFillRemaining(
                  child: NetworkStateView(
                    isEmpty: true,
                    emptyTitle: 'No courses found',
                    emptyMessage: searching
                        ? 'No courses matched your search. Try other words.'
                        : 'No courses have been published yet. Check back '
                              'soon for new training videos.',
                    emptyAction: searching
                        ? TextButton(
                            onPressed: _clearSearch,
                            child: const Text('Clear search'),
                          )
                        : null,
                    child: const SizedBox.shrink(),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      searching
                          ? '${state.total} result${state.total == 1 ? '' : 's'} for "${state.query}"'
                          : '${state.total} learning video${state.total == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: courses.length,
                  itemBuilder: (context, i) {
                    final course = courses[i];
                    return CourseCard(
                      key: ValueKey(course.id),
                      course: course,
                      isOwner: notifier.isOwner(course),
                      onWatch: () => _watch(course),
                      onOpenYouTube: () => _openYouTube(course),
                      onOpenExpert: course.expertId.isEmpty
                          ? null
                          : () => _openExpert(course),
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

/// Navy "Learn With Kaammilega" header with the artwork and the search box.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final artWidth = (width * 0.36).clamp(110.0, 200.0);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.white,
                    ),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const Expanded(
                    child: Text(
                      'Resources',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            const TextSpan(
                              children: [
                                TextSpan(text: 'Learn With '),
                                TextSpan(
                                  text: 'Kaammilega',
                                  style: TextStyle(
                                    color: AppColors.brandOrange,
                                  ),
                                ),
                              ],
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Explore verified trade courses, technical '
                            'modules, and skill certifications taught by '
                            'industry experts.',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Image.asset(
                        'assets/images/resources_hero.webp',
                        width: artWidth,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => SizedBox(width: artWidth),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _SearchBox(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search courses by title, topic, or expert name...',
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onClear,
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final CoursesState state;
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
      return const _CourseSkeleton();
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Center(
        child: Text(
          "You've seen all courses",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _CourseSkeleton extends StatelessWidget {
  const _CourseSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 16,
            ),
          ),
          SizedBox(height: 10),
          ShimmerBox(width: 240, height: 14),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 11),
        ],
      ),
    );
  }
}
