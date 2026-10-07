import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../jobs/models/job_filter.dart';
import 'home_section_header.dart';

/// A Home shortcut that opens the Jobs tab with one filter applied.
///
/// Values are the ones employers pick when posting a job (km-frontend
/// recruiter form) and the Jobs filter sends to km-backend:
/// education, job_types, experience_max and genders.
class JobShortcut {
  const JobShortcut({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    this.qualification,
    this.jobType,
    this.experience,
    this.gender,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color tint;

  final String? qualification;
  final String? jobType;
  final String? experience;
  final String? gender;

  /// Only this shortcut's filter, in the city the user already picked.
  JobFilter filterFor(String city) => JobFilter(
    city: city,
    qualification: [?qualification],
    jobTypes: [?jobType],
    experience: experience ?? 'all',
    genders: [?gender],
  );
}

/// "Search Jobs by Qualification" tiles (backend `education` filter).
const qualificationShortcuts = <JobShortcut>[
  JobShortcut(
    label: '10th Pass',
    icon: Icons.menu_book_rounded,
    color: AppColors.blue,
    tint: AppColors.moduleJobsLight,
    qualification: '10th Pass',
  ),
  JobShortcut(
    label: '12th Pass',
    icon: Icons.history_edu_rounded,
    color: AppColors.moduleSkills,
    tint: AppColors.moduleSkillsLight,
    qualification: '12th Pass',
  ),
  JobShortcut(
    label: 'Diploma / ITI',
    icon: Icons.workspace_premium_outlined,
    color: AppColors.moduleExperts,
    tint: AppColors.moduleExpertsLight,
    qualification: 'Diploma',
  ),
  JobShortcut(
    label: 'Graduate',
    icon: Icons.school_outlined,
    color: AppColors.moduleP2P,
    tint: AppColors.moduleP2PLight,
    qualification: 'Graduation',
  ),
  JobShortcut(
    label: 'Post Graduate',
    icon: Icons.school_rounded,
    color: AppColors.moduleServices,
    tint: AppColors.moduleServicesLight,
    qualification: 'Post Graduation',
  ),
];

/// "What type of job do you want?" cards.
const jobTypeShortcuts = <JobShortcut>[
  JobShortcut(
    label: 'Full Time',
    icon: Icons.work_outline_rounded,
    color: AppColors.blue,
    tint: AppColors.moduleJobsLight,
    jobType: 'Full-time',
  ),
  JobShortcut(
    label: 'Part Time',
    icon: Icons.schedule_rounded,
    color: AppColors.accent,
    tint: AppColors.accentLight,
    jobType: 'Part-time',
  ),
  JobShortcut(
    label: 'Fresher Jobs',
    icon: Icons.emoji_people_rounded,
    color: AppColors.moduleSkills,
    tint: AppColors.moduleSkillsLight,
    experience: '0',
  ),
  JobShortcut(
    label: 'Jobs for Women',
    icon: Icons.female_rounded,
    color: AppColors.moduleServices,
    tint: AppColors.moduleServicesLight,
    gender: 'Female',
  ),
];

/// One sideways row of qualification tiles.
class QualificationShortcutsSection extends StatelessWidget {
  const QualificationShortcutsSection({super.key, required this.onSelected});

  final ValueChanged<JobShortcut> onSelected;

  static const double tileWidth = 108;
  static const double rowHeight = 118;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'Search Jobs by Qualification',
          subtitle: 'Roles that match your education',
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Let the card shadows show past the row's edges.
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: qualificationShortcuts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = qualificationShortcuts[index];
              return _QualificationTile(
                item: item,
                onTap: () => onSelected(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QualificationTile extends StatelessWidget {
  const _QualificationTile({required this.item, required this.onTap});

  final JobShortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCardShadow(
      radius: 16,
      child: Semantics(
        button: true,
        label: 'Jobs for ${item.label}',
        excludeSemantics: true,
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: QualificationShortcutsSection.tileWidth,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.tint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of job type cards.
class JobTypeShortcutsSection extends StatelessWidget {
  const JobTypeShortcutsSection({super.key, required this.onSelected});

  final ValueChanged<JobShortcut> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'What Type of Job Do You Want?',
          subtitle: 'Pick one to see matching jobs',
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final width = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in jobTypeShortcuts)
                    SizedBox(
                      width: width,
                      child: _JobTypeCard(
                        item: item,
                        onTap: () => onSelected(item),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JobTypeCard extends StatelessWidget {
  const _JobTypeCard({required this.item, required this.onTap});

  final JobShortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeCardShadow(
      radius: 14,
      child: Semantics(
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
