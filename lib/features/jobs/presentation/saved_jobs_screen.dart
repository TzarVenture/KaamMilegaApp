import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import 'widgets/job_card.dart';

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
    final jobsState = ref.watch(jobsProvider);
    final savedJobIds = jobsState.savedJobIds;

    // Filter jobs that are saved
    final List<Job> savedJobs = jobsState.jobs
        .where((job) => savedJobIds.contains(job.id))
        .toList();

    // Apply optional search filter
    final List<Job> displayedJobs = _searchQuery.trim().isEmpty
        ? savedJobs
        : savedJobs.where((job) {
            final query = _searchQuery.toLowerCase();
            return job.title.toLowerCase().contains(query) ||
                job.company.toLowerCase().contains(query) ||
                job.cityName.toLowerCase().contains(query) ||
                job.location.toLowerCase().contains(query);
          }).toList();

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
                '${savedJobs.length} ${savedJobs.length == 1 ? 'job' : 'jobs'} saved for later',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // 4. Content (Empty State or Saved Jobs List)
              if (savedJobs.isEmpty)
                _buildEmptyState()
              else ...[
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

                if (displayedJobs.isEmpty)
                  _buildNoSearchResults()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedJobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final job = displayedJobs[index];
                      return JobCard(
                        job: job,
                        isSaved: true,
                        onTap: () => context.push('/jobs/${job.id}'),
                        onBookmarkToggle: () {
                          ref.read(jobsProvider.notifier).toggleSaveJob(job.id);
                        },
                        onApply: () => context.push('/jobs/${job.id}'),
                        onChat: () => context.push('/chat'),
                        onCall: () {},
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
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
