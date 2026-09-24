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
import '../../notifications/providers/notification_provider.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import '../repositories/job_repository.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';

/// Job Detail Screen mirroring https://kaammilega.com/jobs/:id
class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  final Job? initialJob;

  const JobDetailScreen({super.key, required this.jobId, this.initialJob});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Job? _job;
  bool _isLoading = true;
  String? _error;
  bool _isApplied = false;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    if (_job != null) {
      _isLoading = false;
    }
    _loadJob();
    _checkAlreadyApplied();
  }

  /// Show "Applied" immediately if the server says this user already applied
  Future<void> _checkAlreadyApplied() async {
    final applied = await ref
        .read(applicationRepositoryProvider)
        .hasApplied(widget.jobId);
    if (applied && mounted) {
      setState(() => _isApplied = true);
    }
  }

  Future<void> _loadJob() async {
    if (_job == null) {
      // Check if jobsProvider has it already
      final cachedJobs = ref.read(jobsProvider).jobs;
      final cached = cachedJobs.where((j) => j.id == widget.jobId).firstOrNull;
      if (cached != null) {
        setState(() {
          _job = cached;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
    }

    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) {
        setState(() {
          _job = job;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        // If we already have job data (from initialJob or cache), keep it smoothly
        if (_job != null) {
          setState(() {
            _isLoading = false;
            _error = null;
          });
          return;
        }

        // Try looking up in riverpod jobsProvider again
        final cachedJobs = ref.read(jobsProvider).jobs;
        final cached = cachedJobs
            .where((j) => j.id == widget.jobId)
            .firstOrNull;
        if (cached != null) {
          setState(() {
            _job = cached;
            _isLoading = false;
            _error = null;
          });
          return;
        }

        // No real job data available: show the "Job Details Unavailable"
        // screen with Retry. (Previously a made-up job was shown here,
        // which users could even apply to.)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _openApplyModal() {
    if (_job == null) return;
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Apply',
        message:
            'Please sign in to your KaamMilega account to apply for ${_job!.title} at ${_job!.company}.',
      );
      return;
    }
    ApplyModalSheet.show(
      context,
      job: _job!,
      onSuccess: () {
        setState(() => _isApplied = true);
      },
    );
  }

  /// Recruiter phone numbers are not shared by the backend yet.
  /// (Previously this dialled a placeholder number / made-up helpline.)
  void _callHR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Calling recruiters is coming soon. Please use Chat to contact the recruiter.',
        ),
      ),
    );
  }

  void _chatWithHR() {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Chat',
        message: 'Please sign in to your KaamMilega account to chat with the recruiter.',
      );
      return;
    }
    final job = _job;
    if (job == null) return;
    openChatWithUser(
      context,
      ref,
      receiverId: job.recruiterId,
      title: '${job.company} Recruiter',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Job Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const JobDetailSkeleton(),
      );
    }

    if (_error != null || _job == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Job Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.error,
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Job Details Unavailable',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unable to load job details at this time. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadJob,
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
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final job = _job!;
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final myApplicationsAsync = ref.watch(myApplicationsProvider);
    final hasAlreadyApplied =
        _isApplied ||
        (myApplicationsAsync.value?.any((a) => a.jobId == widget.jobId) ??
            false);
    final savedJobIds = ref.watch(jobsProvider).savedJobIds;
    final isSaved = savedJobIds.contains(widget.jobId);

    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const ProfileDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () => context.go('/home'),
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
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1E293B),
              size: 22,
            ),
            splashRadius: 20,
            tooltip: 'Search Jobs',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/jobs');
              }
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
        onRefresh: _loadJob,
        child: CustomScrollView(
          slivers: [
            // Deep Navy Top Header Section (media_1789976851914.png)
            SliverToBoxAdapter(
              child: FadeSlideIn(
                offsetY: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0C1738), // Brand Deep Navy
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button & Bookmark Save Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/jobs');
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B)
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'BACK TO SEARCH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                              color: isSaved
                                  ? const Color(0xFFF97316)
                                  : Colors.white70,
                              size: 24,
                            ),
                            onPressed: () {
                              ref
                                  .read(jobsProvider.notifier)
                                  .toggleSaveJob(widget.jobId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isSaved
                                        ? 'Job removed from saved list.'
                                        : 'Job saved to your bookmarks!',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Job Title
                      Text(
                        job.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // DIRECT HIRING
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'DIRECT HIRING',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF97316),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Horizontal Metrics Row (Salary, Location, Experience)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. MONTHLY SALARY
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B)
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '₹',
                                          style: TextStyle(
                                            color: Color(
                                              0xFF10B981,
                                            ), // Bright Emerald Green
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'SALARY',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      job.formattedSalary,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. LOCATION
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B)
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: Color(
                                            0xFF38BDF8,
                                          ), // Bright Sky Blue
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'LOCATION',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      job.cityName.isNotEmpty
                                          ? (job.location.isNotEmpty &&
                                                    job.location != job.cityName
                                                ? '${job.location}, ${job.cityName}'
                                                : job.cityName)
                                          : (job.location.isNotEmpty
                                                ? job.location
                                                : 'Flexible'),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3. EXPERIENCE
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B)
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.access_time_rounded,
                                          color: Color(
                                            0xFFFBBF24,
                                          ), // Bright Golden Amber
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'EXPERIENCE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      job.formattedExperience,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Badges Horizontal Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            // HOT LISTING
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🔥', style: TextStyle(fontSize: 11)),
                                  SizedBox(width: 4),
                                  Text(
                                    'HOT LISTING',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // JOB TYPE
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                job.jobType.isNotEmpty
                                    ? job.jobType.toUpperCase()
                                    : 'FULL-TIME',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // OPENINGS
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${job.vacancies > 0 ? job.vacancies : 1} OPENINGS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // KM VERIFIED
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'KM VERIFIED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Social proof: Candidates applied
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Color(0xFF60A5FA),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CANDIDATES APPLIED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white60,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${job.applicantCount > 0 ? job.applicantCount : 90}+ People Interested',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Detail Sections
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Job Highlights
                  _SectionCard(
                    title: 'Job Highlights',
                    child: Column(
                      children: [
                        _HighlightRow(
                          icon: Icons.access_time_filled_rounded,
                          label: 'Job Shift & Type',
                          value: '${job.jobType} • Day Shift',
                        ),
                        const Divider(height: 20),
                        _HighlightRow(
                          icon: Icons.apartment_rounded,
                          label: 'City & Location',
                          value: job.formattedLocation,
                        ),
                        const Divider(height: 20),
                        _HighlightRow(
                          icon: Icons.person_rounded,
                          label: 'Eligible Gender',
                          value: job.gender.isNotEmpty
                              ? job.gender
                              : 'All Genders Welcome',
                        ),
                        const Divider(height: 20),
                        _HighlightRow(
                          icon: Icons.school_rounded,
                          label: 'Education Level',
                          value: job.education.isNotEmpty
                              ? job.education
                              : '10th Pass or Above',
                        ),
                        if (job.weOffer.isNotEmpty) ...[
                          const Divider(height: 20),
                          _HighlightRow(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Key Benefit',
                            value: job.weOffer.first,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Skills & Requirements
                  if (job.requirements.isNotEmpty)
                    _SectionCard(
                      title: 'Skills & Requirements',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: job.requirements.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    skill,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  if (job.requirements.isNotEmpty) const SizedBox(height: 16),

                  // 3. Job Description
                  _SectionCard(
                    title: 'Job Description',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.description.isNotEmpty ? job.description : 'No specific description provided. Candidate will receive full role details during HR interview.',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Candidates can contact HR directly for immediate joining.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Contact Person / Recruiter
                  _SectionCard(
                    title: 'Contact Person',
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${job.company} HR Desk',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'HIRING MANAGER • DIRECT RECRUITER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textLight,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. "Just 3 Step To Get Your Dream Job"
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.topMatchCardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.topMatchBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Just 3 Steps To Get Hired',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16),
                        _StepItem(
                          number: '01',
                          title: 'Apply Now',
                          desc: 'Submit your interest in 1 tap',
                        ),
                        _StepItem(
                          number: '02',
                          title: 'Fix Interview',
                          desc: 'Connect with HR team directly',
                        ),
                        _StepItem(
                          number: '03',
                          title: 'Get Hired',
                          desc: 'Start your exciting new job opportunity',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80), // Padding for sticky bottom bar
                ]),
              ),
            ),
          ],
        ),
      ),

      // Fixed Bottom Action Bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Call button
            IconButton.filledTonal(
              onPressed: _callHR,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                minimumSize: const Size(50, 50),
              ),
              icon: const Icon(Icons.phone_outlined, size: 22),
            ),

            const SizedBox(width: 10),

            // Chat button
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _chatWithHR,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text(
                  'CHAT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Apply Now / Applied button
            Expanded(
              flex: 3,
              child: PressableScale(
                child: hasAlreadyApplied
                    ? InkWell(
                        onTap: () =>
                            context.push('/applications/${widget.jobId}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'APPLIED',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : !isAuthenticated
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF94A3B8,
                          ), // Slate gray for guest mode
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            showAuthPromptDialog(
                              context,
                              title: 'Sign In to Apply',
                              message:
                                  'Please sign in to your KaamMilega account to apply for ${job.title} at ${job.company}.',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'APPLY NOW',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryGradientStart,
                              AppColors.primaryGradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _openApplyModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'APPLY NOW',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      index: 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
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
            Row(
              children: [
                // Small brand accent before each section title
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final bool isLast;

  const _StepItem({
    required this.number,
    required this.title,
    required this.desc,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
