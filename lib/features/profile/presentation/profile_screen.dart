import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../applications/repositories/application_repository.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';

/// Full-featured Candidate Profile & CV Screen
/// Specialized exclusively for Job Seekers / Candidates
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _openEditProfileDialog(UserProfile user) {
    final nameCtrl = TextEditingController(text: user.name);
    final cityCtrl = TextEditingController(text: user.city);
    final emailCtrl = TextEditingController(text: user.email);
    final expDetailCtrl = TextEditingController(text: user.experienceDetail);
    String selectedGender = user.gender.isNotEmpty ? user.gender : 'Male';
    String selectedEdu = user.educationLevel.isNotEmpty ? user.educationLevel : '12th Pass';
    String selectedExp = user.workExperience.isNotEmpty ? user.workExperience : 'Fresher';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Candidate Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'City',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Gender', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Male', 'Female', 'Other'].map((g) {
                      final isSel = selectedGender == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedGender = g);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Highest Education', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['Below 10th', '10th Pass', '12th Pass', 'Diploma', 'Graduate'].map((e) {
                      final isSel = selectedEdu == e;
                      return ChoiceChip(
                        label: Text(e, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedEdu = e);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: expDetailCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Experience Summary',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).updateProfile({
                        'name': nameCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'gender': selectedGender,
                        'education_level': selectedEdu,
                        'work_experience': selectedExp,
                        'experience_detail': expDetailCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddSkillDialog() {
    final skillCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a Skill', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: TextField(
          controller: skillCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. 2-Wheeler Driving, English, Excel',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final skill = skillCtrl.text.trim();
              if (skill.isNotEmpty) {
                await ref.read(authProvider.notifier).addSkill(skill);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _callHR() async {
    final uri = Uri(scheme: 'tel', path: '1800123456');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HR Support Helpline: 1800-123-456')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final applicationCount = applicationsAsync.asData?.value.length ?? 0;

    if (authState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text(
            'Candidate Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const ProfileSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text(
          'Candidate Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (authState.isAuthenticated && user != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit Profile',
              onPressed: () => _openEditProfileDialog(user),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Candidate Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B1641), Color(0xFF5E2769)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B1641).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user?.name.isNotEmpty == true ? user!.name : 'Job Seeker',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.mobile.isNotEmpty == true ? '+91 ${user!.mobile}' : 'Mobile verified',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (user?.city.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    user!.city,
                                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat('Applications', '$applicationCount', Icons.work_history_rounded),
                      _buildQuickStat('Status', user?.isRegistered == true ? 'Active' : 'Guest', Icons.check_circle_outline_rounded),
                      _buildQuickStat('Cost', '₹0 Free', Icons.currency_rupee_rounded),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. My Applications Shortcut Card
            InkWell(
              onTap: () => context.push('/my-applications'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bookmark_added_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Applied Jobs',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$applicationCount job application${applicationCount == 1 ? '' : 's'} tracked live',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 3. Candidate Details & Qualifications
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Candidate Details',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      if (user != null)
                        GestureDetector(
                          onTap: () => _openEditProfileDialog(user),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Gender', user?.gender.isNotEmpty == true ? user!.gender : 'Not set'),
                  _buildDetailRow('Education', user?.educationLevel.isNotEmpty == true ? user!.educationLevel : 'Not set'),
                  _buildDetailRow('Experience', user?.workExperience.isNotEmpty == true ? user!.workExperience : 'Fresher'),
                  _buildDetailRow('Preferred City', user?.city.isNotEmpty == true ? user!.city : 'All India'),
                  if (user?.email.isNotEmpty == true)
                    _buildDetailRow('Email', user!.email),
                  if (user?.experienceDetail.isNotEmpty == true)
                    _buildDetailRow('Summary', user!.experienceDetail),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. Target Job Categories
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Job Roles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Roles you receive priority job alerts for:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (user?.jobCategories.isNotEmpty == true)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user!.jobCategories.map((role) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text(
                      'No specific roles selected. Tap Edit to pick your target categories.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 5. Skills Tags
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Skills & Badges',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      TextButton.icon(
                        onPressed: _openAddSkillDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Skill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (user?.skills.isNotEmpty == true)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user!.skills.map((s) {
                        return Chip(
                          backgroundColor: Colors.grey.shade100,
                          label: Text(s),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text(
                      'Add your skills (e.g. Driver, Cook, Delivery, Hindi, English) to help recruiters find you.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 6. Help & Support
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildSupportTile(
                    icon: Icons.headset_mic_rounded,
                    title: 'Call HR Helpline',
                    subtitle: 'Toll-free candidate support: 1800-123-456',
                    onTap: _callHR,
                  ),
                  const Divider(height: 20),
                  _buildSupportTile(
                    icon: Icons.shield_outlined,
                    title: '100% Free Job Guarantee',
                    subtitle: 'Never pay any money for any job application',
                    onTap: () {},
                  ),
                  const Divider(height: 20),
                  _buildSupportTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Jobseeker FAQs',
                    subtitle: 'Frequently asked questions for job seekers',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 7. Auth Button (Sign In / Logout)
            if (authState.isAuthenticated)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/home');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.w700)),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        ],
      ),
    );
  }
}

