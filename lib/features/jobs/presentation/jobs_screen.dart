import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../applications/presentation/apply_modal.dart';
import '../../cities/presentation/city_selector_sheet.dart';
import '../providers/jobs_provider.dart';
import 'widgets/filter_modal.dart';
import 'widgets/job_card.dart';
import 'widgets/pagination_bar.dart';
import 'widgets/promo_banner.dart';
import 'widgets/top_match_banner.dart';

/// Main Jobs Screen matching https://kaammilega.com/jobs
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _applyingJobId;

  @override
  void initState() {
    super.initState();
    final currentSearch = ref.read(jobsProvider).filter.searchQuery;
    if (currentSearch.isNotEmpty) {
      _searchController.text = currentSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _handleCall() async {
    final uri = Uri(scheme: 'tel', path: '1800123456');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HR Support Helpline: +91 98765 43210')),
        );
      }
    }
  }

  void _handleChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting to recruiter chat...')),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            // Logo Branding (clickable to go to home)
            GestureDetector(
              onTap: () => context.go('/home'),
              child: Image.asset('assets/images/logo.jpg', height: 32),
            ),

            const SizedBox(width: 10),

            // City Selector Pill
            GestureDetector(
              onTap: () => _openCitySelector(filter.city),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        filter.city,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded, color: AppColors.textPrimary),
            onPressed: () => context.push('/my-applications'),
            tooltip: 'My Applications',
          ),
        ],
      ),

      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(jobsProvider.notifier).fetchJobs(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Search & Filter Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onSubmitted: (val) {
                        ref.read(jobsProvider.notifier).setSearchQuery(val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search jobs, role, or company...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(jobsProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Results Counter & Filter Trigger Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Jobs Count
                        Row(
                          children: [
                            const Text(
                              'Showing ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              jobsState.isLoading
                                  ? '...'
                                  : '${jobsState.totalJobs} Jobs',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryGradientStart,
                              ),
                            ),
                          ],
                        ),

                        // Filters button
                        ElevatedButton.icon(
                          onPressed: _openFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 1,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: Text(
                            activeFilters > 0 ? 'Filters ($activeFilters)' : 'Filters',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Active Search/City Subtitle
                    if (filter.searchQuery.isNotEmpty || filter.city != 'All')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Results for ${filter.searchQuery.isNotEmpty ? '"${filter.searchQuery}"' : 'all roles'}'
                          '${filter.city != 'All' ? ' in ${filter.city}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Top Match Banner
            const SliverToBoxAdapter(
              child: TopMatchBanner(),
            ),

            // Jobs List or Loading/Empty State
            if (jobsState.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  childCount: 3,
                ),
              )
            else if (jobsState.jobs.isEmpty)
              SliverToBoxAdapter(
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
                      const Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No jobs found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Try adjusting your search query or removing filters',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          _searchController.clear();
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
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final job = jobsState.jobs[index];
                    final isTopMatch = filter.page == 1 && index < 3;

                    return JobCard(
                      job: job,
                      isTopMatch: isTopMatch,
                      isApplying: _applyingJobId == job.id,
                      onTap: () => context.push('/jobs/${job.id}'),
                      onApply: () => _handleApply(job.id),
                      onChat: _handleChat,
                      onCall: _handleCall,
                    );
                  },
                  childCount: jobsState.jobs.length,
                ),
              ),

            // Promo Banner ("Waiting to get a job?")
            const SliverToBoxAdapter(
              child: PromoBanner(),
            ),

            // Pagination Controls
            SliverToBoxAdapter(
              child: PaginationBar(
                currentPage: filter.page,
                totalPages: jobsState.totalPages,
                onPageChanged: _onPageChanged,
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }
}
