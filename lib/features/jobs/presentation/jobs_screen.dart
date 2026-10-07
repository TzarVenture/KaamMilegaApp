import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../applications/repositories/application_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/open_chat.dart';
import '../../cities/presentation/city_dropdown.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import '../../../shared/widgets/network_state_view.dart';
import 'widgets/filter_modal.dart';
import 'widgets/job_card.dart';
import 'widgets/jobs_hero_card.dart';
import 'widgets/pagination_bar.dart';
import 'widgets/promo_banner.dart';
import '../../../shared/widgets/fade_slide_in.dart';

/// Main Jobs Screen matching https://kaammilega.com/jobs
class JobsScreen extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateTab;

  const JobsScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  bool _isSearchVisible = false;
  String _selectedSort = 'Newest First';
  bool _filterSavedOnly = false;

  @override
  void initState() {
    super.initState();
    final currentSearch = ref.read(jobsProvider).filter.searchQuery;
    if (currentSearch.isNotEmpty) {
      _searchController.text = currentSearch;
      _isSearchVisible = true;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(jobsProvider.notifier).setSearchQuery(query.trim());
    });
  }

  /// City dropdown under the tapped widget ([anchor]).
  void _openCitySelector(BuildContext anchor, String currentCity) {
    showCityDropdown(
      anchor,
      currentCity: currentCity,
      onSelected: (selectedCity) {
        ref.read(jobsProvider.notifier).setCity(selectedCity);
      },
    );
  }

  void _openFilters() {
    final currentFilter = ref.read(jobsProvider).filter;
    FilterModalSheet.show(
      context,
      initialFilter: currentFilter,
      onApply: (updatedFilter) {
        ref.read(jobsProvider.notifier).applyFilter(updatedFilter);
      },
    );
  }

  /// Recruiter phone numbers are not shared by the backend yet, so there is
  /// no real number to dial. (Previously this dialled a placeholder number
  /// and showed a made-up helpline.)
  void _handleCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Calling recruiters is coming soon. Please use Chat to contact the recruiter.',
        ),
      ),
    );
  }

  /// Open a real chat with the job's recruiter
  void _handleChat(Job job) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Chat',
        message: 'Please sign in to your KaamMilega account to chat with the recruiter.',
      );
      return;
    }
    openChatWithUser(
      context,
      ref,
      receiverId: job.recruiterId,
      title: '${job.company} Recruiter',
    );
  }

  void _onPageChanged(int page) {
    ref.read(jobsProvider.notifier).setPage(page);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A search started elsewhere (Home > Popular Categories) shows in the
    // search box, so the user can see and clear it.
    ref.listen<String>(jobsProvider.select((s) => s.filter.searchQuery), (
      previous,
      next,
    ) {
      if (next == _searchController.text.trim()) return;
      _searchController.text = next;
      if (next.isNotEmpty && !_isSearchVisible) {
        setState(() => _isSearchVisible = true);
      }
    });
    final jobsState = ref.watch(jobsProvider);
    final filter = jobsState.filter;
    final activeFilters = filter.activeFilterCount;
    final myApplicationsAsync = ref.watch(myApplicationsProvider);
    final appliedJobIds =
        myApplicationsAsync.value?.map((a) => a.jobId).toSet() ?? {};

    // Apply sorting and saved filter if requested
    var displayedJobs = List.of(jobsState.jobs);
    if (_filterSavedOnly) {
      displayedJobs = displayedJobs
          .where((j) => jobsState.savedJobIds.contains(j.id))
          .toList();
    }
    if (_selectedSort == 'Highest Salary') {
      displayedJobs.sort((a, b) => b.salaryMax.compareTo(a.salaryMax));
    } else if (_selectedSort == 'Lowest Salary') {
      displayedJobs.sort((a, b) => a.salaryMin.compareTo(b.salaryMin));
    } else if (_selectedSort == 'Most Vacancies') {
      displayedJobs.sort((a, b) => b.vacancies.compareTo(a.vacancies));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: ProfileDrawer(onNavigateTab: widget.onNavigateTab),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(0);
            } else {
              context.go('/home');
            }
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/logo_text.png',
                  height: 18,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // 1. Search Icon
          IconButton(
            icon: Icon(
              _isSearchVisible
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
              color: const Color(0xFF1E293B),
              size: 22,
            ),
            splashRadius: 20,
            tooltip: 'Search Jobs',
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible && _searchController.text.isNotEmpty) {
                  _searchController.clear();
                  ref.read(jobsProvider.notifier).setSearchQuery('');
                }
              });
            },
          ),

          // 2. Notification bell (shared button)
          const NotificationBellButton(color: Color(0xFF1E293B)),

          // 3. Hamburger Menu (Drawer)
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Color(0xFF1E293B),
              size: 24,
            ),
            splashRadius: 20,
            tooltip: 'Menu',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(jobsProvider.notifier).fetchJobs(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Expandable Sleek Search Bar (When search icon is clicked)
            if (_isSearchVisible)
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  offsetY: 8,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      onSubmitted: (val) {
                        _debounceTimer?.cancel();
                        ref
                            .read(jobsProvider.notifier)
                            .setSearchQuery(val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search jobs, role, or company...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _debounceTimer?.cancel();
                                  _searchController.clear();
                                  ref
                                      .read(jobsProvider.notifier)
                                      .setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Navy intro card (scrolls away; the toolbar below stays)
            SliverToBoxAdapter(
              child: JobsHeroCard(
                // The total is shown only when it means "all open jobs"
                openJobs:
                    jobsState.isLoading ||
                        activeFilters > 0 ||
                        filter.searchQuery.isNotEmpty ||
                        filter.city != 'All'
                    ? null
                    : jobsState.totalJobs,
                savedCount: jobsState.savedJobIds.length,
                onSavedJobs: () => context.push('/saved-jobs'),
              ),
            ),

            // ============================================================
            // COMPACT TOOLBAR: job count, sort and filters (stays on top)
            // ============================================================
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedBarDelegate(
                height:
                    58 *
                    MediaQuery.textScalerOf(context)
                        .scale(1)
                        .clamp(1.0, 1.6)
                        .toDouble(),
                child: _buildToolbar(
                  countLabel: jobsState.isLoading
                      ? 'Loading jobs...'
                      : _jobCountLabel(
                          _filterSavedOnly
                              ? displayedJobs.length
                              : jobsState.totalJobs,
                        ),
                  activeFilters: activeFilters,
                ),
              ),
            ),

            // Active search / city / saved-only, with a way to change it
            if (filter.searchQuery.isNotEmpty ||
                filter.city != 'All' ||
                _filterSavedOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        'Filtered by: '
                        '${filter.searchQuery.isNotEmpty ? '"${filter.searchQuery}" ' : ''}'
                        '${filter.city != 'All' ? 'in ${filter.city} ' : ''}'
                        '${_filterSavedOnly ? '• Saved Only' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (filter.city != 'All')
                        Builder(
                          builder: (anchor) => GestureDetector(
                            onTap: () => _openCitySelector(anchor, filter.city),
                            child: const Text(
                              '(Change City)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // Inline Error Banner if jobs exist but last action failed
            if (jobsState.errorMessage != null && jobsState.jobs.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Failed to update job feed. Pull down or retry.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(jobsProvider.notifier).fetchJobs(),
                        child: const Text(
                          'Retry',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Offline Cache Notice
            if (jobsState.cachedTimestamp != null)
              SliverToBoxAdapter(
                child: CachedDataBadge(timestamp: jobsState.cachedTimestamp!),
              ),

            // Jobs List or Loading/Error/Empty State
            if (jobsState.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const JobCardSkeleton(),
                  childCount: 4,
                ),
              )
            else if (jobsState.errorMessage != null && jobsState.jobs.isEmpty)
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 38,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to load jobs',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Please check your internet connection or try again in a few moments.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.read(jobsProvider.notifier).fetchJobs(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Retry Connection',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (displayedJobs.isEmpty)
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 38,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const SizedBox(height: 12),
                        Text(
                          _filterSavedOnly ? 'No saved jobs' : 'No jobs found',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _filterSavedOnly
                              ? 'Bookmark jobs to easily view them here'
                              : 'Try adjusting your search query or removing filters',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            _debounceTimer?.cancel();
                            _searchController.clear();
                            setState(() {
                              _filterSavedOnly = false;
                              _selectedSort = 'Newest First';
                            });
                            ref.read(jobsProvider.notifier).clearAllFilters();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Clear All Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final job = displayedJobs[index];

                  return FadeSlideIn(
                    index: index,
                    child: JobCard(
                      job: job,
                      isApplied: appliedJobIds.contains(job.id),
                      isSaved: jobsState.savedJobIds.contains(job.id),
                      onBookmarkToggle: () =>
                          ref.read(jobsProvider.notifier).toggleSaveJob(job.id),
                      onTap: () => context.push('/jobs/${job.id}', extra: job),
                      // "View & Apply" opens the job page, where the user
                      // reads the details and taps Apply for Position.
                      onApply: () =>
                          context.push('/jobs/${job.id}', extra: job),
                      onChat: () => _handleChat(job),
                      onCall: _handleCall,
                    ),
                  );
                }, childCount: displayedJobs.length),
              ),

            // Promo Banner ("Waiting to get a job?")
            const SliverToBoxAdapter(child: PromoBanner()),

            // Pagination Controls
            SliverToBoxAdapter(
              child: PaginationBar(
                currentPage: filter.page,
                totalPages: jobsState.totalPages,
                onPageChanged: _onPageChanged,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  static const Map<String, String> _sortShortLabels = {
    'Newest First': 'Newest',
    'Highest Salary': 'Highest pay',
    'Lowest Salary': 'Lowest pay',
    'Most Vacancies': 'Most openings',
  };

  static String _jobCountLabel(int count) =>
      '$count ${count == 1 ? 'job' : 'jobs'}';

  /// One slim bar: "12 jobs", sort menu and Filters (with active count).
  Widget _buildToolbar({
    required String countLabel,
    required int activeFilters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: PopupMenuButton<String>(
              tooltip: 'Sort jobs',
              initialValue: _selectedSort,
              onSelected: (val) => setState(() => _selectedSort = val),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              itemBuilder: (ctx) => [
                for (final option in _sortShortLabels.keys)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
              ],
              child: _ToolbarPill(
                icon: Icons.swap_vert_rounded,
                label: _sortShortLabels[_selectedSort] ?? _selectedSort,
                trailing: Icons.keyboard_arrow_down_rounded,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(10),
              child: _ToolbarPill(
                icon: Icons.tune_rounded,
                label: activeFilters > 0
                    ? 'Filters ($activeFilters)'
                    : 'Filters',
                highlighted: activeFilters > 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded control used in the Jobs toolbar.
class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.icon,
    required this.label,
    this.trailing,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.blue : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryLight : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.primaryLightBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 2),
            Icon(trailing, size: 16, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}

/// Keeps the toolbar visible at the top while the job list scrolls.
class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_PinnedBarDelegate oldDelegate) => true;
}
