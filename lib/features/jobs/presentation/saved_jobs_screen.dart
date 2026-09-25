import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import 'widgets/job_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/network_state_view.dart';

/// Screen for displaying Bookmarked / Saved Jobs
/// Matching the exact design from KaamMilega (media_1789975854042.png)
class SavedJobsScreen extends ConsumerStatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  ConsumerState<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends ConsumerState<SavedJobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedJobIds = ref.watch(jobsProvider.select((s) => s.savedJobIds));
    // Every saved job, loaded by ID (not only the ones on the current Jobs
    // page). No request at all when nothing is saved.
    final savedAsync = savedJobIds.isEmpty
        ? null
        : ref.watch(savedJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Smooth page background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Back to All Jobs Button
              InkWell(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/jobs');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Back to All Jobs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Header: Icon + Title
              const Row(
                children: [
                  Icon(
                    Icons.bookmark_added_outlined,
                    size: 34,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Saved Jobs',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // 3. Subtitle
              Text(
                '${savedJobIds.length} ${savedJobIds.length == 1 ? 'job' : 'jobs'} saved for later',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // 4. Content: empty / loading / error / saved jobs
              if (savedAsync == null)
                _buildEmptyState()
              else
                savedAsync.when(
                  // Keep the list on screen while it refreshes (e.g. after
                  // removing a bookmark).
                  skipLoadingOnReload: true,
                  loading: () => const Column(
                    children: [
                      JobCardSkeleton(),
                      SizedBox(height: 12),
                      JobCardSkeleton(),
                      SizedBox(height: 12),
                      JobCardSkeleton(),
                    ],
                  ),
                  error: (error, _) => SizedBox(
                    // The state view scrolls, so it needs a bounded height
                    // inside this scrolling page.
                    height: 420,
                    child: NetworkStateView.fromError(
                      error,
                      onRetry: () {
                        // Re-run the failed per-job requests too.
                        ref.invalidate(savedJobDetailProvider);
                        ref.invalidate(savedJobsProvider);
                      },
                    ),
                  ),
                  data: _buildSavedJobs,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedJobs(List<SavedJobEntry> entries) {
    final query = _searchQuery.trim().toLowerCase();
    final available = entries.where((e) => e.job != null).map((e) => e.job!);
    final List<Job> displayedJobs = query.isEmpty
        ? available.toList()
        : available.where((job) {
            return job.title.toLowerCase().contains(query) ||
                job.company.toLowerCase().contains(query) ||
                job.cityName.toLowerCase().contains(query) ||
                job.location.toLowerCase().contains(query);
          }).toList();
    // Saved jobs the server no longer has (HTTP 404), listed after the rest
    // so the user can remove them. Hidden while searching.
    final unavailable = query.isEmpty
        ? entries.where((e) => e.isUnavailable).toList()
        : const <SavedJobEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar for saved jobs
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search saved jobs...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        if (displayedJobs.isEmpty && unavailable.isEmpty)
          _buildNoSearchResults()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedJobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: Builder(
                builder: (context) {
                  final job = displayedJobs[index];
                  return JobCard(
                    job: job,
                    isSaved: true,
                    onTap: () => context.push('/jobs/${job.id}', extra: job),
                    onBookmarkToggle: () {
                      ref.read(jobsProvider.notifier).toggleSaveJob(job.id);
                    },
                    onApply: () => context.push('/jobs/${job.id}', extra: job),
                    onChat: () => context.push('/chat'),
                    onCall: () {},
                  );
                },
              ),
            ),
          ),

        for (final entry in unavailable) ...[
          const SizedBox(height: 12),
          _buildUnavailableJob(entry.id),
        ],
      ],
    );
  }

  /// A saved job that no longer exists on the server (HTTP 404).
  Widget _buildUnavailableJob(String jobId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.work_off_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This saved job is no longer available.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(jobsProvider.notifier).toggleSaveJob(jobId),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Empty state matching screenshot media_1789975854042.png
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Badge with Bookmark Icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF), // Blue 50
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.bookmark_added_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Title
          const Text(
            'No Saved Jobs Found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // Description
          const Text(
            "You haven't bookmarked any jobs yet.\nBrowse job listings and click the bookmark\nicon to save them for later.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 24),

          // Browse Jobs Button
          ElevatedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/jobs');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Browse Jobs',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'No matching saved jobs found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try searching with different keywords.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
