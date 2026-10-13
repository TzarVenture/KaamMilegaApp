import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/models/user_profile.dart';
import '../models/job.dart';

/// Tappable chips on a job card.
enum JobCardLink { jobType, experience, openings, verifiedEmployer }

/// Opens the page behind a job card chip:
/// - job type -> more jobs of that type (GET /jobs?job_types=)
/// - experience -> jobs open to that experience (GET /jobs?experience_max=)
/// - openings -> members like you for this role (GET /community/users)
/// - KM Verified Employer -> the employer's company page
void openJobLink(BuildContext context, Job job, JobCardLink link) {
  switch (link) {
    case JobCardLink.jobType:
      final type = job.jobType.trim();
      if (type.isEmpty) return;
      context.push(
        Uri(path: '/related-jobs', queryParameters: {'type': type}).toString(),
      );
    case JobCardLink.experience:
      context.push(
        Uri(
          path: '/related-jobs',
          queryParameters: {
            'exp': '${job.experienceMax < 0 ? 0 : job.experienceMax}',
            'label': job.formattedExperience,
          },
        ).toString(),
      );
    case JobCardLink.openings:
      context.push('/similar-people/${job.id}', extra: job);
    case JobCardLink.verifiedEmployer:
      if (job.recruiterId.isEmpty) return;
      context.push('/company/${job.recruiterId}');
  }
}

/// Call button on a job. The backend does not share a recruiter phone
/// number for jobs yet, so nothing is dialled: a sheet explains this and
/// offers Chat (which works today). Never dials a made-up number.
Future<void> showRecruiterCallSheet(
  BuildContext context, {
  required VoidCallback onChat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_disabled_outlined,
                color: AppColors.blue,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Phone number not shared',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This recruiter has not shared a contact number. Send them a '
              'message on KaamMilega instead.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onChat();
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Chat with recruiter'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Orders [experts] by how well they fit [job]: shared skills first, then
/// words of the job title in their headline / about, then the same city.
/// Ties keep the server's order. Experts with no match stay at the end, so
/// the list is never empty when experts exist. Pure, so it is easy to test.
List<UserProfile> rankExpertsForJob(List<UserProfile> experts, Job job) {
  String norm(String s) => s.trim().toLowerCase();
  final skills = job.requirements.map(norm).where((s) => s.isNotEmpty).toSet();
  final words = norm(job.title)
      .split(RegExp(r'[^a-z0-9+#]+'))
      .where((w) => w.length >= 3)
      .toSet();
  final city = norm(job.cityName);

  final scored = <({int score, int index, UserProfile user})>[];
  for (var i = 0; i < experts.length; i++) {
    final e = experts[i];
    final shared = e.skills.map(norm).where(skills.contains).length;
    final text = '${norm(e.headline)} ${norm(e.about)}';
    final role = words.any(text.contains);
    final sameCity = city.isNotEmpty && norm(e.city) == city;
    scored.add((
      score: shared * 3 + (role ? 2 : 0) + (sameCity ? 1 : 0),
      index: i,
      user: e,
    ));
  }
  scored.sort(
    (a, b) => a.score != b.score
        ? b.score.compareTo(a.score)
        : a.index.compareTo(b.index),
  );
  return [for (final s in scored) s.user];
}
