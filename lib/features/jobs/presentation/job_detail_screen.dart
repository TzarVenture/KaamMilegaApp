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
import '../../../shared/widgets/notification_bell_button.dart';
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
        onRefresh: _loadJob,
        child: CustomScrollView(
          slivers: [
            // Compact header: back, title, company · city, salary, facts
            SliverToBoxAdapter(
              child: FadeSlideIn(
                offsetY: 8,
                child: _JobHeader(
                  job: job,
                  isSaved: isSaved,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/jobs');
                    }
                  },
                  onToggleSave: () {
                    ref.read(jobsProvider.notifier).toggleSaveJob(widget.jobId);
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
                          label: 'Job Type',
                          value: job.jobType,
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
                              : 'Any / Not specified',
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

      // Fixed bottom action bar: call, chat, apply
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            _BarIconButton(
              icon: Icons.phone_outlined,
              tooltip: 'Call',
              onPressed: _callHR,
            ),
            const SizedBox(width: 8),
            _BarIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Chat with recruiter',
              onPressed: _chatWithHR,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PressableScale(
                child: hasAlreadyApplied
                    ? Material(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () =>
                              context.push('/applications/${widget.jobId}'),
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            height: 48,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Applied · View status',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: isAuthenticated
                            ? _openApplyModal
                            : () => showAuthPromptDialog(
                                context,
                                title: 'Sign In to Apply',
                                message:
                                    'Please sign in to your KaamMilega account to apply for ${job.title} at ${job.company}.',
                              ),
                        // Orange: the app's main action colour (accent).
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Apply for Position',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

/// Top of the job page: back and save, title with company and city, the
/// salary, and short facts. Everything shown comes from the job itself.
class _JobHeader extends StatelessWidget {
  const _JobHeader({
    required this.job,
    required this.isSaved,
    required this.onBack,
    required this.onToggleSave,
  });

  final Job job;
  final bool isSaved;
  final VoidCallback onBack;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final company = job.company.trim();
    final city = job.cityName.trim().isNotEmpty
        ? job.cityName.trim()
        : job.location.trim();
    final subtitle = [company, city].where((v) => v.isNotEmpty).join(' · ');
    final posted = job.postedLabel;
    final salaryBoth = job.salaryMin > 0 && job.salaryMax > 0;

    // Navy panel in the app's brand colours (white text on top)
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandNavy, AppColors.navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: isSaved ? 'Remove from saved' : 'Save job',
                onPressed: onToggleSave,
                icon: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isSaved ? AppColors.accent : Colors.white,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.accent, AppColors.accentBright],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: company.isEmpty
                          ? const Icon(
                              Icons.work_outline_rounded,
                              color: AppColors.onAccent,
                            )
                          : Text(
                              company[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onAccent,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.displayTitle,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            (job.hasSalary ? AppColors.success : Colors.white)
                                .withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.currency_rupee_rounded,
                        size: 17,
                        color: job.hasSalary
                            ? Color.lerp(AppColors.success, Colors.white, 0.4)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: job.hasSalary
                                  ? job.formattedSalary
                                  : 'Salary disclosed at interview',
                              style: TextStyle(
                                fontSize: job.hasSalary ? 16 : 14,
                                fontWeight: job.hasSalary
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: job.hasSalary
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            if (salaryBoth)
                              TextSpan(
                                text: ' / month',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (city.isNotEmpty)
                      _Fact(
                        icon: Icons.location_on_rounded,
                        label: city,
                        color: AppColors.moduleServices,
                      ),
                    _Fact(
                      icon: Icons.schedule_rounded,
                      label: job.formattedExperience,
                      color: AppColors.moduleEvents,
                    ),
                    if (job.jobType.trim().isNotEmpty)
                      _Fact(
                        icon: Icons.work_rounded,
                        label: job.jobType.trim(),
                        color: AppColors.moduleExperts,
                      ),
                    _Fact(
                      icon: Icons.groups_rounded,
                      color: AppColors.moduleSkills,
                      label:
                          '${job.vacancies} ${job.vacancies == 1 ? 'opening' : 'openings'}',
                    ),
                    // Real count only; nothing shown when nobody applied yet
                    if (job.applicantCount > 0)
                      _Fact(
                        icon: Icons.how_to_reg_rounded,
                        color: AppColors.moduleP2P,
                        label: '${job.applicantCount} applied',
                      ),
                    if (posted.isNotEmpty)
                      _Fact(
                        icon: Icons.today_rounded,
                        label: posted,
                        color: AppColors.accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;

  /// Brand colour for the icon; lightened so it stays bright on navy.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 13,
              color: Color.lerp(color, Colors.white, 0.35),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 21)),
      ),
    );
  }
}
