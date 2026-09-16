import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../network/providers/network_provider.dart';
import '../../network/repositories/network_repository.dart';

/// Full-featured Candidate Profile & CV Screen
/// Specialized exclusively for Job Seekers / Candidates
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  // -------------------------------------------------------------------
  // PHOTO UPLOAD & BACKGROUND / PROFILE MODALS
  // -------------------------------------------------------------------
  Future<void> _pickAndUploadProfilePhoto([
    ImageSource source = ImageSource.gallery,
  ]) async {
    if (!ref.read(authProvider).isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to upload your profile photo.'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.push('/login');
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final filename = image.name;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Uploading profile photo...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final success = await ref
          .read(authProvider.notifier)
          .uploadProfilePhoto(bytes, filename);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile photo updated successfully!'
                : 'Failed to update profile photo. Please try again.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteProfilePhoto() async {
    if (!ref.read(authProvider).isAuthenticated) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Removing profile photo...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final success = await ref
          .read(authProvider.notifier)
          .deleteProfilePhoto();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile photo removed successfully!'
                : 'Failed to remove profile photo. Please try again.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickAndUploadCoverPhoto([
    ImageSource source = ImageSource.gallery,
  ]) async {
    if (!ref.read(authProvider).isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to customize your background photo.'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.push('/login');
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final filename = image.name;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Uploading background photo...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final success = await ref
          .read(authProvider.notifier)
          .uploadCoverPhoto(bytes, filename);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Background cover photo updated successfully!'
                : 'Failed to update background photo. Please try again.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteCoverPhoto() async {
    if (!ref.read(authProvider).isAuthenticated) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Removing background photo...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final success = await ref.read(authProvider.notifier).deleteCoverPhoto();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Background photo removed successfully!'
                : 'Failed to remove background photo. Please try again.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showAddBackgroundPhotoModal() {
    final user = ref.read(authProvider).user;
    final coverImage = user?.coverImage ?? '';
    final hasCover = coverImage.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Background Photo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 170,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2FA),
                    borderRadius: BorderRadius.circular(20),
                    image: hasCover
                        ? DecorationImage(
                            image: NetworkImage(coverImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !hasCover
                      ? Center(
                          child: Container(
                            width: 80,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9333EA),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9333EA)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.image_outlined,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadCoverPhoto(ImageSource.gallery);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF9333EA),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadCoverPhoto(ImageSource.camera);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: Color(0xFF9333EA),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteCoverPhoto();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFF9333EA),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddProfilePhotoModal() {
    final user = ref.read(authProvider).user;
    final profileImage = user?.profileImage ?? '';
    final hasAvatar = profileImage.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile Photo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                      image: hasAvatar
                          ? DecorationImage(
                              image: NetworkImage(profileImage),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasAvatar
                        ? CircleAvatar(
                            radius: 115,
                            backgroundColor: AppColors.heroBg,
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 100,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadProfilePhoto(ImageSource.gallery);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF9333EA),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadProfilePhoto(ImageSource.camera);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: Color(0xFF9333EA),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteProfilePhoto();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFF9333EA),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // EDIT PERSONAL & PROFESSIONAL INFO DIALOG
  // -------------------------------------------------------------------
  void _openEditProfileDialog(UserProfile user) {
    final nameParts = user.name.trim().split(' ');
    final initialFirstName = nameParts.isNotEmpty ? nameParts.first : '';
    final initialLastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    final firstNameCtrl = TextEditingController(text: initialFirstName);
    final lastNameCtrl = TextEditingController(text: initialLastName);
    final additionalNameCtrl = TextEditingController();
    final headlineCtrl = TextEditingController(text: user.headline);
    final cityCtrl = TextEditingController(text: user.city);
    final emailCtrl = TextEditingController(text: user.email);
    final aboutCtrl = TextEditingController(text: user.about);

    String selectedPronoun = 'Please Select';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        'Edit Intro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // First Name & Last Name in Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'First Name*',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Last Name*',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Additional Name
                  TextField(
                    controller: additionalNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Additional Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pronouns
                  DropdownButtonFormField<String>(
                    initialValue: selectedPronoun,
                    decoration: InputDecoration(
                      labelText: 'Pronouns',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items:
                        [
                          'Please Select',
                          'He/Him (He/Him/His)',
                          'She/Her (She/Her/Hers)',
                          'They/Them (They/Them/Theirs)',
                          'Custom',
                        ].map((p) {
                          return DropdownMenuItem(value: p, child: Text(p));
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedPronoun = val);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(text: 'Let others know how to refer to you. '),
                        TextSpan(
                          text: 'Learn More About Gender Pronouns.',
                          style: TextStyle(
                            color: Color(0xFF9333EA),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Headline*
                  TextField(
                    controller: headlineCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Headline*',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // City / Location*
                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'City / Location*',
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Email Address
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // About / Summary
                  TextField(
                    controller: aboutCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'About / Summary',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Bottom Right Save Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final fname = firstNameCtrl.text.trim();
                        final lname = lastNameCtrl.text.trim();
                        final addName = additionalNameCtrl.text.trim();
                        final computedName = fname.isNotEmpty
                            ? '$fname $lname ${addName.isNotEmpty ? "($addName)" : ""}'
                                  .trim()
                            : user.name;

                        final ok = await ref
                            .read(authProvider.notifier)
                            .updateProfile({
                              'name': computedName,
                              'headline': headlineCtrl.text.trim(),
                              'city': cityCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'about': aboutCtrl.text.trim(),
                            });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Intro updated successfully!'
                                    : 'Failed to update intro.',
                              ),
                              backgroundColor: ok
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9333EA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

  // -------------------------------------------------------------------
  // IMAGE & DOCUMENT PICKERS
  // -------------------------------------------------------------------

  Future<void> _pickAndUploadResumePdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ok = await ref
              .read(authProvider.notifier)
              .uploadResumePdf(file.bytes!, file.name);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Resume uploaded successfully!'
                      : 'Failed to upload resume.',
                ),
                backgroundColor: ok ? AppColors.success : AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _viewResume(String resumeUrl) async {
    if (resumeUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No resume uploaded yet.')));
      return;
    }
    final uri = Uri.parse(resumeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Resume URL: $resumeUrl')));
      }
    }
  }

  // -------------------------------------------------------------------
  // EMAIL OTP VERIFICATION DIALOG
  // -------------------------------------------------------------------
  void _showEmailOtpDialog(String currentEmail) {
    final emailCtrl = TextEditingController(text: currentEmail);
    final otpCtrl = TextEditingController();
    bool otpSent = false;
    bool isVerifying = false;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verify Email Address',
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
                const SizedBox(height: 12),
                Text(
                  otpSent
                      ? 'Enter 6-digit verification code sent to ${emailCtrl.text}:'
                      : 'Confirm your email address to receive OTP code:',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                if (!otpSent) ...[
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            setModalState(() => isVerifying = true);
                            final sent = await ref
                                .read(authProvider.notifier)
                                .sendEmailOtp(emailCtrl.text.trim());
                            setModalState(() {
                              isVerifying = false;
                              if (sent) otpSent = true;
                            });
                            if (!sent && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to send email OTP.'),
                                  backgroundColor: AppColors.error,
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
                    child: isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send Verification OTP',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ] else ...[
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '6-Digit OTP Code',
                      prefixIcon: const Icon(Icons.mark_email_read_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            setModalState(() => isVerifying = true);
                            final ok = await ref
                                .read(authProvider.notifier)
                                .verifyEmailOtp(
                                  emailCtrl.text.trim(),
                                  otpCtrl.text.trim(),
                                );
                            setModalState(() => isVerifying = false);
                            if (mounted && context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Email verified successfully!'
                                        : 'Invalid OTP code. Please try again.',
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
                    child: isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify OTP & Confirm',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // OPEN TO WORK & PROVIDING SERVICES MODAL
  // -------------------------------------------------------------------
  void _showOpenToModal(UserProfile user) {
    final workCtrl = TextEditingController(
      text: user.openToWork.isNotEmpty
          ? user.openToWork
          : 'Computer Science roles, Software Engineering Internships',
    );
    final servicesCtrl = TextEditingController(
      text: user.providingServices.isNotEmpty
          ? user.providingServices
          : 'Web Development, Technical Writing, and Go Microservices',
    );

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
                    'Open To Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Open to Work (Target Job Roles)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: workCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Software Engineering, Delivery Driver',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Providing Services (Freelance / Gig Services)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: servicesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Web Development, AC Repair, Delivery',
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
                        'open_to_work': workCtrl.text.trim(),
                        'providing_services': servicesCtrl.text.trim(),
                      });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Preferences updated!'
                              : 'Failed to update preferences.',
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
                  'Save Preferences',
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
  // CONTACT INFO MODAL
  // -------------------------------------------------------------------
  void _showContactInfoDialog(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contact & Public Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow(
              'Full Name',
              user.name.isNotEmpty ? user.name : 'Candidate',
            ),
            _buildDetailRow(
              'Mobile Number',
              user.mobile.isNotEmpty ? user.mobile : 'Not added',
            ),
            _buildDetailRow(
              'Email Address',
              user.email.isNotEmpty ? user.email : 'Not added',
            ),
            _buildDetailRow(
              'Location',
              user.city.isNotEmpty ? user.city : 'India',
            ),
            _buildDetailRow('Profile URL', 'www.kaammilega.com/in/${user.id}'),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // REFILL WALLET CREDITS MODAL
  // -------------------------------------------------------------------
  void _showRefillWalletModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Refill Wallet Credits',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Add wallet balance to unlock premium recruiter contacts & instant gig dispatches.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Redirecting to Razorpay UPI Checkout...',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '₹99\nBasic Topup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Redirecting to Razorpay UPI Checkout...',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '₹199\nPopular Pack',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // ADD PROFILE SECTION SHEET
  // -------------------------------------------------------------------
  void _showAddSectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Profile Section',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Add Education History',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('School, college, or university degree'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddEducationDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.business_center_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Add Work Experience',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Past job roles and companies'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddExperienceDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Add Skill Tag',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Key skills to attract recruiters'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddSkillDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Upload Resume (PDF / DOC)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Upload your CV document'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadResumePdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // MORE PROFILE OPTIONS SHEET
  // -------------------------------------------------------------------
  void _showMoreProfileMenu(UserProfile? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'More Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.share_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Share Profile Link',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Share your digital CV link with recruiters',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Profile URL copied: www.kaammilega.com/in/${user?.id ?? ''}',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Download Resume PDF',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _viewResume(user?.resumeUrl ?? '');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.headset_mic_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Call HR Helpline',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _callHR();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // LINKEDIN HERO BANNER WIDGET
  // -------------------------------------------------------------------
  Widget _buildLinkedInHeroBanner(UserProfile? user, int connectionsCount) {
    final coverImage = user?.coverImage ?? '';
    final profileImage = user?.profileImage ?? '';
    final hasCover = coverImage.isNotEmpty;
    final hasAvatar = profileImage.isNotEmpty;
    final isAuth = ref.watch(authProvider).isAuthenticated;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Photo Container with Camera Edit Button & Avatar
          SizedBox(
            height: 185,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _showAddBackgroundPhotoModal,
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.heroBg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      image: hasCover
                          ? DecorationImage(
                              image: NetworkImage(coverImage),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasCover
                        ? Center(
                            child: Icon(
                              Icons.gradient_rounded,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 64,
                            ),
                          )
                        : null,
                  ),
                ),

                // Camera button for Cover Photo
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _showAddBackgroundPhotoModal,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                // Overlapping Avatar Circle with Camera Edit Button
                Positioned(
                  top: 92,
                  left: 20,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showAddProfilePhotoModal,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.heroBg,
                            backgroundImage: hasAvatar
                                ? NetworkImage(profileImage)
                                : null,
                            child: !hasAvatar
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showAddProfilePhotoModal,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Name, Headline, City & Connections Subheader
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user != null && user.name.isNotEmpty
                          ? user.name
                          : (isAuth ? 'Candidate Name' : 'Guest User'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (user != null)
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _openEditProfileDialog(user),
                      ),
                  ],
                ),
                Text(
                  user != null && user.headline.isNotEmpty
                      ? user.headline
                      : (isAuth
                            ? 'Add a headline to your profile'
                            : 'Sign in to build your candidate profile'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: user != null && user.headline.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      user != null && user.city.isNotEmpty
                          ? user.city
                          : 'India',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                    GestureDetector(
                      onTap: () =>
                          user != null ? _showContactInfoDialog(user) : null,
                      child: const Text(
                        'Contact Info',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/network'),
                      child: Text(
                        '$connectionsCount Connections',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Email Unverified Warning Banner
                if (user != null && !user.isEmailVerified) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email Unverified (${user.email.isNotEmpty ? user.email : 'sunnyVerma12@gmail.com'})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showEmailOtpDialog(user.email),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Verify Email Now',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Buttons Row: Open To, Add Profile Section, More
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () =>
                          user != null ? _showOpenToModal(user) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Open To',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _showAddSectionSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Add Profile Section',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _showMoreProfileMenu(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'More',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // WALLET CREDITS CARD WIDGET
  // -------------------------------------------------------------------
  Widget _buildWalletCreditsCard(UserProfile? user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1435),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wallet Credits',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${user?.walletBalance ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _showRefillWalletModal,
            icon: const Icon(Icons.currency_rupee_rounded, size: 14),
            label: const Text(
              'Refill Wallet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // TWIN OPEN TO CARDS WIDGET
  // -------------------------------------------------------------------
  Widget _buildTwinOpenToCards(UserProfile? user) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Open To Work',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (user != null)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _showOpenToModal(user),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  user?.openToWork.isNotEmpty == true ? user!.openToWork : 'Computer Science roles, Software Engineering Internships...',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Providing Services',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (user != null)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _showOpenToModal(user),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  user?.providingServices.isNotEmpty == true
                      ? user!.providingServices
                      : 'Web Development, Technical Writing, and Go Microservices...',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // PROFILE STRENGTH / COMPLETENESS BAR CARD (F16)
  // -------------------------------------------------------------------
  Widget _buildProfileCompletenessCard(UserProfile? user) {
    if (user == null) return const SizedBox.shrink();

    int percentage = 0;
    final missingItems = <String>[];

    if (user.name.isNotEmpty && user.name != 'Candidate') {
      percentage += 15;
    } else {
      missingItems.add('Add full name');
    }

    if (user.headline.isNotEmpty) {
      percentage += 15;
    } else {
      missingItems.add('Add headline');
    }

    if (user.isEmailVerified) {
      percentage += 15;
    } else {
      missingItems.add('Verify email address');
    }

    if (user.about.isNotEmpty) {
      percentage += 15;
    } else {
      missingItems.add('Add About summary');
    }

    if (user.resumeUrl.isNotEmpty) {
      percentage += 15;
    } else {
      missingItems.add('Upload Resume PDF');
    }

    if (user.experience.isNotEmpty) {
      percentage += 15;
    } else {
      missingItems.add('Add work experience');
    }

    if (user.skills.isNotEmpty) {
      percentage += 10;
    } else {
      missingItems.add('Add skill tags');
    }

    String level;
    Color levelColor;
    if (percentage >= 80) {
      level = 'All-Star Candidate Profile';
      levelColor = Colors.green;
    } else if (percentage >= 50) {
      level = 'Intermediate Profile';
      levelColor = Colors.amber.shade800;
    } else {
      level = 'Beginner Profile';
      levelColor = AppColors.primary;
    }

    return Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Completeness',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: levelColor,
                    ),
                  ),
                ],
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              minHeight: 8,
              backgroundColor: AppColors.primaryLight,
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          if (missingItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Next step: ${missingItems.first}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // FREE NOW FOR GIGS AVAILABILITY TOGGLE CARD (F30)
  // -------------------------------------------------------------------
  Widget _buildGigAvailabilityToggleCard(UserProfile? user) {
    if (user == null) return const SizedBox.shrink();

    final isAvailable = user.isAvailableForGigs;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isAvailable ? const Color(0xFFF3E8FF) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAvailable ? const Color(0xFFD8B4FE) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAvailable
                  ? const Color(0xFF9333EA)
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Free Now for Gigs',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isAvailable ? 'AVAILABLE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Notify recruiters you are available for immediate gig assignments',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isAvailable,
            activeTrackColor: const Color(0xFF9333EA),
            onChanged: (val) async {
              final ok = await ref.read(authProvider.notifier).updateProfile({
                'is_available_for_gigs': val,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? (val
                                ? 'Status updated: You are now FREE for immediate gigs!'
                                : 'Status updated: Gig availability paused.')
                          : 'Failed to update availability.',
                    ),
                    backgroundColor: ok
                        ? (val ? AppColors.success : AppColors.primary)
                        : AppColors.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // ANALYTICS CARD WIDGET
  // -------------------------------------------------------------------
  Widget _buildAnalyticsCard(UserProfile? user) {
    return Container(
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
            children: const [
              Text(
                'Analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.visibility_off_outlined,
                size: 14,
                color: AppColors.textLight,
              ),
              SizedBox(width: 4),
              Text(
                'Private To You',
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnalyticsMetric(
                '${user?.profileViewsCount ?? 0} Profile Views',
                "Discover who's viewed your profile",
                Icons.bar_chart_rounded,
              ),
              _buildAnalyticsMetric(
                '${user?.postImpressionsCount ?? 0} Post Impressions',
                "Check out who's engaging",
                Icons.ssid_chart_rounded,
              ),
              _buildAnalyticsMetric(
                '${user?.searchAppearancesCount ?? 0} Search Appearances',
                'How often you appear',
                Icons.search_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String title, String subtitle, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // RESUME CARD WIDGET
  // -------------------------------------------------------------------
  Widget _buildResumeCard(UserProfile? user) {
    final hasResume = user != null && user.resumeUrl.isNotEmpty;

    return Container(
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
            children: const [
              Text(
                'Resume & CV Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
            ],
          ),
          const Divider(height: 16),
          Text(
            hasResume
                ? 'Resume Document: Attached & ready for recruiter review'
                : 'No PDF resume document uploaded yet. Upload your CV to stand out!',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickAndUploadResumePdf,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  hasResume ? 'Update Resume' : 'Upload Resume (PDF)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (hasResume) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _viewResume(user.resumeUrl),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text(
                    'View Resume',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // PEOPLE WHO VIEWED / SUGGESTED NETWORK WIDGET
  // -------------------------------------------------------------------
  Widget _buildPeopleWhoViewedCard() {
    final suggestions = [
      {
        'id': 'u1',
        'name': 'Arjun Sharma',
        'headline': 'Software Engineer at TCS',
        'mutual': '10 Mutual Connects',
      },
      {
        'id': 'u2',
        'name': 'Priya Patel',
        'headline': 'Product Manager at Flipkart',
        'mutual': '5 Mutual Connects',
      },
    ];

    return Container(
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
                'People Who Viewed / Connect',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              TextButton(
                onPressed: () => context.push('/network'),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          Column(
            children: suggestions.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.heroBg,
                      child: Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            s['headline']!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            s['mutual']!,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(networkRepositoryProvider)
                              .sendInvitation(s['id']!);
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Invitation sent to ${s['name']}!',
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Already connected or request pending.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // OUR EXPERTS WIDGET
  // -------------------------------------------------------------------
  Widget _buildOurExpertsCard() {
    return Container(
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
            children: const [
              Text(
                'Our Experts & Mentors',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Icon(Icons.verified_rounded, color: AppColors.primary),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Career Mentorship',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'GATE & Tech Interview Mentor',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Expert mentorship session booking sheet...',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Book Session',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
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
          const SnackBar(content: Text('HR Support Helpline: 1800 123 456')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final connectionsCount = ref
        .watch(connectionsProvider)
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
                    // 1. LinkedIn Hero Cover & Header Card
                    _buildLinkedInHeroBanner(user, connectionsCount),

                    const SizedBox(height: 16),

                    // 2. Profile Strength / Completeness Bar Card (F16)
                    _buildProfileCompletenessCard(user),

                    const SizedBox(height: 16),

                    // 3. Wallet Credits Card
                    _buildWalletCreditsCard(user),

                    const SizedBox(height: 16),

                    // 4. Twin Cards: Open To Work & Providing Services
                    _buildTwinOpenToCards(user),

                    const SizedBox(height: 16),

                    // 5. Free Now for Immediate Gigs Switch Card (F30)
                    _buildGigAvailabilityToggleCard(user),

                    const SizedBox(height: 16),

                    // 4. Analytics Card (Private To You)
                    _buildAnalyticsCard(user),

                    const SizedBox(height: 16),

                    // 5. Resume PDF Upload & Download Card
                    _buildResumeCard(user),

                    const SizedBox(height: 16),

                    // 6. People Who Viewed / Network Suggestions Card
                    _buildPeopleWhoViewedCard(),

                    const SizedBox(height: 16),

                    // 7. Our Experts Preview Card
                    _buildOurExpertsCard(),

                    const SizedBox(height: 16),

                    // 8. Personal & Professional Details Card
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
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logged out successfully.'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
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
