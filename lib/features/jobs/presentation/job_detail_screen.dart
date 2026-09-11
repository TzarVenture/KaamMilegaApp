import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../applications/presentation/apply_modal.dart';
import '../models/job.dart';
import '../repositories/job_repository.dart';

/// Job Detail Screen mirroring https://kaammilega.com/jobs/:id
class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailScreen({
    super.key,
    required this.jobId,
  });

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  Job? _job;
  bool _isLoading = true;
  String? _error;
  bool _isApplied = false;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final job = await ref.read(jobRepositoryProvider).getJobById(widget.jobId);
      if (mounted) {
        setState(() {
          _job = job;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openApplyModal() {
    if (_job == null) return;
    ApplyModalSheet.show(
      context,
      job: _job!,
      onSuccess: () {
        setState(() => _isApplied = true);
      },
    );
  }

  void _callHR() async {
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

  void _chatWithHR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting to recruiter chat...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading Job Magic...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _job == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Job details not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadJob,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final job = _job!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Deep Purple Top Header Section
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.deepPurpleHeader,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button Row
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'BACK TO SEARCH',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Job Title
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Company + Direct Hiring
                  Row(
                    children: [
                      Text(
                        job.company.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGradientStart,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Direct Hiring',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Metric Stat Cards (Salary, Location, Experience)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatBox(
                          iconWidget: const Text(
                            '₹',
                            style: TextStyle(
                              color: AppColors.primaryGradientStart,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          label: 'BUDGET / MONTH',
                          value: job.formattedSalary,
                        ),
                        Container(width: 1, height: 36, color: Colors.white12),
                        _StatBox(
                          iconWidget: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primaryGradientStart,
                            size: 16,
                          ),
                          label: 'LOCATION',
                          value: job.cityName,
                        ),
                        Container(width: 1, height: 36, color: Colors.white12),
                        _StatBox(
                          iconWidget: const Icon(
                            Icons.work_history_rounded,
                            color: AppColors.primaryGradientStart,
                            size: 16,
                          ),
                          label: 'EXPERIENCE',
                          value: job.formattedExperience,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderBadge(
                        text: 'HOT',
                        color: AppColors.hotRose,
                        bgColor: AppColors.hotRose.withValues(alpha: 0.2),
                      ),
                      _HeaderBadge(
                        text: job.jobType.toUpperCase(),
                        color: Colors.white,
                        bgColor: Colors.white12,
                      ),
                      _HeaderBadge(
                        text: '${job.vacancies} OPENINGS',
                        color: Colors.white,
                        bgColor: Colors.white12,
                      ),
                      _HeaderBadge(
                        text: 'KM VERIFIED',
                        icon: Icons.verified_rounded,
                        color: Colors.white,
                        bgColor: AppColors.verifiedBlue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Social proof: Candidates applied
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          color: AppColors.primaryGradientStart,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Column(
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
                      ],
                    ),
                  ),
                ],
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
                        value: job.gender.isNotEmpty ? job.gender : 'All Genders Welcome',
                      ),
                      const Divider(height: 20),
                      _HighlightRow(
                        icon: Icons.school_rounded,
                        label: 'Education Level',
                        value: job.education.isNotEmpty ? job.education : '10th Pass or Above',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
                              Text(
                                skill,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
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
                        job.description.isNotEmpty
                            ? job.description
                            : 'No specific description provided. Candidate will receive full role details during HR interview.',
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
                            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
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

            // Apply Now button
            Expanded(
              flex: 3,
              child: Container(
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
                  onPressed: _isApplied ? null : _openApplyModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isApplied ? 'APPLIED' : 'APPLY NOW',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontStyle: FontStyle.italic,
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

class _StatBox extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final String value;

  const _StatBox({
    required this.iconWidget,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        iconWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color bgColor;

  const _HeaderBadge({
    required this.text,
    this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
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
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
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
