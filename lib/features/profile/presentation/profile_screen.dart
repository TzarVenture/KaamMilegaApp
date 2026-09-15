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
  // -------------------------------------------------------------------
  // EDIT PERSONAL & PROFESSIONAL INFO DIALOG
  // -------------------------------------------------------------------
  void _openEditProfileDialog(UserProfile user) {
    final nameCtrl = TextEditingController(text: user.name);
    final cityCtrl = TextEditingController(text: user.city);
    final emailCtrl = TextEditingController(text: user.email);
    final headlineCtrl = TextEditingController(text: user.headline);
    final aboutCtrl = TextEditingController(text: user.about);
    final expDetailCtrl = TextEditingController(text: user.experienceDetail);
    String selectedGender = user.gender.isNotEmpty ? user.gender : 'Male';
    String selectedEdu = user.educationLevel.isNotEmpty
        ? user.educationLevel
        : '12th Pass';
    String selectedExp = user.workExperience.isNotEmpty
        ? user.workExperience
        : 'Fresher';

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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: headlineCtrl,
                    decoration: InputDecoration(
                      labelText: 'Profile Headline (e.g. Delivery Driver / Retail Sales)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'City',
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: aboutCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'About / Summary',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Gender',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
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
                        ),
                        onSelected: (val) =>
                            setModalState(() => selectedGender = g),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Education Level',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children:
                        [
                          'Below 10th',
                          '10th Pass',
                          '12th Pass',
                          'Diploma',
                          'Graduate',
                        ].map((e) {
                          final isSel = selectedEdu == e;
                          return ChoiceChip(
                            label: Text(e),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            onSelected: (val) =>
                                setModalState(() => selectedEdu = e),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Total Work Experience',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['Fresher', '1-2 Years', '3-5 Years', '5+ Years']
                        .map((exp) {
                          final isSel = selectedExp == exp;
                          return ChoiceChip(
                            label: Text(exp),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            onSelected: (val) =>
                                setModalState(() => selectedExp = exp),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: expDetailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Experience Summary',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await ref
                          .read(authProvider.notifier)
                          .updateProfile({
                            'name': nameCtrl.text.trim(),
                            'headline': headlineCtrl.text.trim(),
                            'city': cityCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'about': aboutCtrl.text.trim(),
                            'gender': selectedGender,
                            'education_level': selectedEdu,
                            'work_experience': selectedExp,
                            'experience_detail': expDetailCtrl.text.trim(),
                          });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Profile updated successfully!'
                                  : 'Failed to update profile.',
                            ),
                            backgroundColor: ok
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // ADD EDUCATION DIALOG
  // -------------------------------------------------------------------
  void _openAddEducationDialog() {
    final schoolCtrl = TextEditingController();
    final degreeCtrl = TextEditingController();
    final fieldCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                    'Add Education',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: schoolCtrl,
                decoration: InputDecoration(
                  labelText: 'School / University Name*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: degreeCtrl,
                decoration: InputDecoration(
                  labelText: 'Degree / Certificate',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fieldCtrl,
                decoration: InputDecoration(
                  labelText: 'Field of Study',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: InputDecoration(
                        labelText: 'Start Year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: InputDecoration(
                        labelText: 'End Year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (schoolCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final ok = await ref
                      .read(authProvider.notifier)
                      .addEducation(
                        schoolName: schoolCtrl.text,
                        degree: degreeCtrl.text,
                        fieldOfStudy: fieldCtrl.text,
                        startDate: startCtrl.text,
                        endDate: endCtrl.text,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Education added successfully!'
                              : 'Failed to add education.',
                        ),
                        backgroundColor: ok
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Add Education',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // ADD WORK EXPERIENCE DIALOG
  // -------------------------------------------------------------------
  void _openAddExperienceDialog() {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                    'Add Work Experience',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Job Title*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration: InputDecoration(
                  labelText: 'Company Name*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: 'City / Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: InputDecoration(
                        labelText: 'End Date / Present',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty ||
                      companyCtrl.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx);
                  final ok = await ref
                      .read(authProvider.notifier)
                      .addExperience(
                        title: titleCtrl.text,
                        companyName: companyCtrl.text,
                        employmentType: 'Full-time',
                        location: locationCtrl.text,
                        startDate: startCtrl.text,
                        endDate: endCtrl.text,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Experience added successfully!'
                              : 'Failed to add experience.',
                        ),
                        backgroundColor: ok
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Add Experience',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // ADD SKILL DIALOG
  // -------------------------------------------------------------------
  void _openAddSkillDialog() {
    final skillCtrl = TextEditingController();
    final suggestedSkills = [
      'Bike Driving',
      'Customer Support',
      'Hindi Fluency',
      'Packaging',
      'Sales',
      'Security',
      'Warehouse Operation',
      'AC Repair',
      'Data Entry',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                    'Add Skill Tag',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: skillCtrl,
                decoration: InputDecoration(
                  labelText: 'Enter Skill Name',
                  hintText: 'e.g. Delivery, Customer Support',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Popular Skills',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedSkills.map((s) {
                  return ActionChip(
                    label: Text(s),
                    backgroundColor: AppColors.primaryLight,
                    labelStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    onPressed: () {
                      skillCtrl.text = s;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (skillCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final ok = await ref
                      .read(authProvider.notifier)
                      .addSkill(skillCtrl.text);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Skill added successfully!'
                              : 'Failed to add skill.',
                        ),
                        backgroundColor: ok
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Add Skill Tag',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
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
          const SnackBar(content: Text('HR Support Helpline: 1800 123 456')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final myAppsCount = ref
        .watch(myApplicationsProvider)
        .maybeWhen(data: (list) => list.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Candidate Profile & CV',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (authState.isAuthenticated && user != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit Profile',
              onPressed: () => _openEditProfileDialog(user),
            ),
        ],
      ),
      body: authState.isLoading
          ? const ShimmerLoadingList(count: 3)
          : RefreshIndicator(
              onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 1. Candidate Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.heroBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.heroBg.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white24,
                            backgroundImage:
                                (user != null && user.profileImage.isNotEmpty)
                                ? NetworkImage(user.profileImage)
                                : null,
                            child: (user == null || user.profileImage.isEmpty)
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user?.name.isNotEmpty == true
                                ? user!.name
                                : 'Candidate Profile',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          if (user != null && user.headline.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.headline,
                              style: const TextStyle(
                                color: AppColors.heroAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            user?.city.isNotEmpty == true
                                ? '${user!.city} • Candidate'
                                : 'Jobseeker',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStat(
                                'Applications',
                                '$myAppsCount',
                                Icons.work_outline_rounded,
                              ),
                              _buildQuickStat(
                                'Status',
                                authState.isAuthenticated ? 'Active' : 'Guest',
                                Icons.verified_user_rounded,
                              ),
                              _buildQuickStat(
                                'City',
                                user?.city.isNotEmpty == true
                                    ? user!.city
                                    : 'India',
                                Icons.location_on_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Personal & Professional Details Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Personal Info',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (user != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  onPressed: () => _openEditProfileDialog(user),
                                ),
                            ],
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Mobile Number',
                            user?.mobile.isNotEmpty == true
                                ? user!.mobile
                                : 'Not added',
                          ),
                          _buildDetailRow(
                            'Email Address',
                            user?.email.isNotEmpty == true
                                ? user!.email
                                : 'Not added',
                          ),
                          _buildDetailRow(
                            'Gender',
                            user?.gender.isNotEmpty == true
                                ? user!.gender
                                : 'Not specified',
                          ),
                          _buildDetailRow(
                            'Education',
                            user?.educationLevel.isNotEmpty == true
                                ? user!.educationLevel
                                : '12th Pass',
                          ),
                          _buildDetailRow(
                            'Experience',
                            user?.workExperience.isNotEmpty == true
                                ? user!.workExperience
                                : 'Fresher',
                          ),
                          if (user != null && user.about.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'About Me',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.about,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. Candidate Skills Tagging Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Skill Tags',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.primary,
                                ),
                                onPressed: _openAddSkillDialog,
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (user == null || user.skills.isEmpty)
                            const Text(
                              'No skills added yet. Tap + to add skills to attract recruiters!',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: user.skills.map((s) {
                                return Chip(
                                  label: Text(s),
                                  backgroundColor: AppColors.primaryLight,
                                  labelStyle: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. Education History List Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Education History',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.primary,
                                ),
                                onPressed: _openAddEducationDialog,
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (user == null || user.education.isEmpty)
                            const Text(
                              'No education entries added yet. Tap + to add education history.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            )
                          else
                            Column(
                              children: user.education.map((edu) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.school_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              edu.schoolName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${edu.degree} ${edu.fieldOfStudy}'
                                                  .trim(),
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (edu.startDate.isNotEmpty)
                                              Text(
                                                '${edu.startDate} - ${edu.endDate}',
                                                style: const TextStyle(
                                                  color: AppColors.textLight,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. Work Experience List Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Work Experience',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.primary,
                                ),
                                onPressed: _openAddExperienceDialog,
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (user == null || user.experience.isEmpty)
                            const Text(
                              'No work experience added yet. Tap + to add work experience.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            )
                          else
                            Column(
                              children: user.experience.map((exp) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.business_center_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${exp.companyName} • ${exp.location}'
                                                  .trim(),
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (exp.startDate.isNotEmpty)
                                              Text(
                                                '${exp.startDate} - ${exp.endDate}',
                                                style: const TextStyle(
                                                  color: AppColors.textLight,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),

                    // 6. Candidate Activity & Networking (Applications, Interviews, Connections, Chats)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Job Activity & Network',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSupportTile(
                            icon: Icons.work_history_rounded,
                            title: 'Applied Jobs',
                            subtitle:
                                'Track status of your submitted applications',
                            onTap: () => context.push('/my-applications'),
                          ),
                          const Divider(height: 20),
                          _buildSupportTile(
                            icon: Icons.event_available_rounded,
                            title: 'Interview Schedule',
                            subtitle:
                                'View upcoming recruiter interviews & calls',
                            onTap: () => context.push('/interviews'),
                          ),
                          const Divider(height: 20),
                          _buildSupportTile(
                            icon: Icons.people_alt_rounded,
                            title: 'My Network & Connections',
                            subtitle:
                                'Manage connections & pending invitations',
                            onTap: () => context.push('/network'),
                          ),
                          const Divider(height: 20),
                          _buildSupportTile(
                            icon: Icons.chat_bubble_rounded,
                            title: 'Messages & Chats',
                            subtitle:
                                '1-on-1 real-time messaging with recruiters',
                            onTap: () => context.push('/chats'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 7. Support & Helpline Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildSupportTile(
                            icon: Icons.headset_mic_rounded,
                            title: 'Call HR Helpline',
                            subtitle:
                                'Toll-free candidate support: 1800-123-456',
                            onTap: _callHR,
                          ),
                          const Divider(height: 20),
                          _buildSupportTile(
                            icon: Icons.shield_outlined,
                            title: '100% Free Job Guarantee',
                            subtitle:
                                'Never pay any money for any job application',
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Logout',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => context.push('/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text(
                          'Sign In / Register',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
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
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        ],
      ),
    );
  }
}
