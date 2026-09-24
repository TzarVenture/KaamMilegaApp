import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../applications/presentation/apply_modal.dart';
import '../../applications/repositories/application_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/open_chat.dart';
import '../../cities/presentation/city_selector_sheet.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import '../../../shared/widgets/network_state_view.dart';
import 'widgets/filter_modal.dart';
import 'widgets/job_card.dart';
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
  String? _applyingJobId;
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

  void _openCitySelector(String currentCity) {
    CitySelectorSheet.show(
      context,
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

  void _handleApply(String jobId) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Apply',
        message: 'Please sign in or register to apply for jobs and connect with recruiters.',
      );
      return;
    }
    final jobs = ref.read(jobsProvider).jobs;
    final job = jobs.firstWhere((j) => j.id == jobId);

    ApplyModalSheet.show(
      context,
      job: job,
      onSuccess: () {
        setState(() => _applyingJobId = null);
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
    final jobsState = ref.watch(jobsProvider);
    final filter = jobsState.filter;
    final activeFilters = filter.activeFilterCount;
    final myApplicationsAsync = ref.watch(myApplicationsProvider);
    final appliedJobIds =
        myApplicationsAsync.value?.map((a) => a.jobId).toSet() ?? {};
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

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
      backgroundColor: const Color(0xFFF8FAFC),
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

          // 2. Notification Bell with Badge
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF1E293B),
                  size: 24,
                ),
                if (unreadNotifs > 0)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            splashRadius: 20,
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),

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

            // ============================================================
            // 1. HERO HEADER CARD (Matching Web Screenshot)
            // ============================================================
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF030712),
                      Color(0xFF0F172A),
                      Color(0xFF0B193D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF030712).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Pill: ✨ Verified Indian Employment Portal
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFFBBF24),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Verified Indian Employment Portal',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main Headline: Find Jobs & Connect Direct
                    const Text(
                      'Find Jobs & Connect Direct',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    const Text(
                      'Direct candidate-to-recruiter hiring with 1-click apply and real-time interview management.',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 3 Metric Badges
                    Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      children: [
                        _buildHeroMetric(
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF34D399),
                          // Real total from the server (was a made-up "1,250+")
                          text: '${jobsState.totalJobs} Active Listings',
                        ),
                        _buildHeroMetric(
                          icon: Icons.apartment_rounded,
                          color: const Color(0xFF60A5FA),
                          text: 'Verified Companies',
                        ),
                        _buildHeroMetric(
                          icon: Icons.bolt_rounded,
                          color: const Color(0xFFFBBF24),
                          text: 'Instant Application',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Saved Jobs Button
                    InkWell(
                      onTap: () {
                        context.push('/saved-jobs');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_rounded,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Saved Jobs (${jobsState.savedJobIds.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ============================================================
            // 2. POSITIONS COUNT & FILTER CARD (Matching Web Screenshot)
            // ============================================================
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Showing [N] Available Positions"
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16.5,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        children: [
                          const TextSpan(text: 'Showing  '),
                          TextSpan(
                            text: jobsState.isLoading
                                ? '...'
                                : '${displayedJobs.length} Available Positions',
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Sort & Filter Action Pills (Responsive Wrap to prevent any overflow)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // 1. Sort Dropdown Pill
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            setState(() => _selectedSort = val);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'Newest First',
                              child: Text(
                                'Newest First',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'Highest Salary',
                              child: Text(
                                'Highest Salary',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'Lowest Salary',
                              child: Text(
                                'Lowest Salary',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'Most Vacancies',
                              child: Text(
                                'Most Vacancies',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.swap_vert_rounded,
                                  size: 16,
                                  color: Color(0xFF334155),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sort: $_selectedSort',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2. Filters Pill Button
                        InkWell(
                          onTap: _openFilters,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.tune_rounded,
                                  size: 15,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  activeFilters > 0
                                      ? 'Filters ($activeFilters)'
                                      : 'Filters',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // City / Search Indicator if active
                    if (filter.searchQuery.isNotEmpty ||
                        filter.city != 'All' ||
                        _filterSavedOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
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
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (filter.city != 'All')
                              GestureDetector(
                                onTap: () => _openCitySelector(filter.city),
                                child: const Text(
                                  '(Change City)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

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
                          style: TextStyle(fontWeight: FontWeight.w800),
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
                            fontWeight: FontWeight.w800,
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
                            style: TextStyle(fontWeight: FontWeight.w800),
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
                            fontWeight: FontWeight.w800,
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
                  final isTopMatch = filter.page == 1 && index == 0;

                  return FadeSlideIn(
                    index: index,
                    child: JobCard(
                      job: job,
                      isTopMatch: isTopMatch,
                      isApplying: _applyingJobId == job.id,
                      isApplied: appliedJobIds.contains(job.id),
                      isSaved: jobsState.savedJobIds.contains(job.id),
                      onBookmarkToggle: () =>
                          ref.read(jobsProvider.notifier).toggleSaveJob(job.id),
                      onTap: () => context.push('/jobs/${job.id}', extra: job),
                      onApply: () => _handleApply(job.id),
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

  Widget _buildHeroMetric({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFF1F5F9),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
