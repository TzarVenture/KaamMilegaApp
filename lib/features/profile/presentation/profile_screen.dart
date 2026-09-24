import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../network/providers/network_provider.dart';

/// Full-featured Candidate Profile & CV Screen
/// Specialized exclusively for Job Seekers / Candidates
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _showCompletenessDetails = false;

  // -------------------------------------------------------------------
  // PHOTO UPLOAD & BACKGROUND / PROFILE MODALS
  // -------------------------------------------------------------------
  Future<void> _pickAndUploadProfilePhoto([
    ImageSource source = ImageSource.gallery,
  ]) async {
    if (!ref.read(authProvider).isAuthenticated) {
      if (mounted) {
        showAuthPromptDialog(
          context,
          title: 'Sign In Required',
          message: 'Please sign in to upload your profile photo.',
        );
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
        showAuthPromptDialog(
          context,
          title: 'Sign In Required',
          message: 'Please sign in to customize your background photo.',
        );
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
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to update your background photo.',
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final coverImage = ApiConstants.resolveImageUrl(user?.coverImage ?? '');
    final hasCover =
        coverImage.isNotEmpty &&
        (coverImage.startsWith('http://') || coverImage.startsWith('https://'));

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
                            onError: (_, _) {},
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
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to update your profile photo.',
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final profileImage = ApiConstants.resolveImageUrl(user?.profileImage ?? '');
    final hasAvatar =
        profileImage.isNotEmpty &&
        (profileImage.startsWith('http://') ||
            profileImage.startsWith('https://'));

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
                              onError: (_, _) {},
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
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to edit your profile information.',
      );
      return;
    }

    final nameParts = user.name.trim().split(' ');
    final initialFirstName = nameParts.isNotEmpty ? nameParts.first : '';
    final initialLastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    final firstNameCtrl = TextEditingController(text: initialFirstName);
    final lastNameCtrl = TextEditingController(text: initialLastName);
    final additionalNameCtrl = TextEditingController();
    final headlineCtrl = TextEditingController(text: user.headline);

    String selectedPronoun = user.gender.isNotEmpty
        ? user.gender
        : 'Please Select';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '* Indicates required',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // First Name & Last Name in Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'First Name*',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: firstNameCtrl,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Last Name*',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: lastNameCtrl,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Additional Name
                        const Text(
                          'Additional Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: additionalNameCtrl,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pronouns
                        const Text(
                          'Pronouns',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  [
                                    'Please Select',
                                    'He/Him (He/Him/His)',
                                    'She/Her (She/Her/Hers)',
                                    'They/Them (They/Them/Theirs)',
                                    'Custom',
                                  ].contains(selectedPronoun)
                                  ? selectedPronoun
                                  : 'Please Select',
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF64748B),
                              ),
                              items:
                                  [
                                    'Please Select',
                                    'He/Him (He/Him/His)',
                                    'She/Her (She/Her/Hers)',
                                    'They/Them (They/Them/Theirs)',
                                    'Custom',
                                  ].map((p) {
                                    final isPlaceholder = p == 'Please Select';
                                    return DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p,
                                        style: TextStyle(
                                          color: isPlaceholder
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF1E293B),
                                          fontSize: 15,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedPronoun = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            children: [
                              TextSpan(
                                text: 'Let others know how to refer to you. ',
                              ),
                              TextSpan(
                                text: 'Learn More About Gender Pronouns.',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Headline*
                        const Text(
                          'Headline*',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: headlineCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Bottom Right Save Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      final fname = firstNameCtrl.text.trim();
                      final lname = lastNameCtrl.text.trim();
                      final addName = additionalNameCtrl.text.trim();

                      if (fname.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your first name'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      final computedName = fname.isNotEmpty
                          ? '$fname $lname ${addName.isNotEmpty ? "($addName)" : ""}'
                                .trim()
                          : user.name;

                      final Map<String, dynamic> updatePayload = {
                        'name': computedName,
                        'headline': headlineCtrl.text.trim(),
                      };
                      if (selectedPronoun != 'Please Select') {
                        updatePayload['gender'] = selectedPronoun;
                      }

                      final ok = await ref
                          .read(authProvider.notifier)
                          .updateProfile(updatePayload);

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
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // EDIT ABOUT / SUMMARY DIALOG
  // -------------------------------------------------------------------
  void _showEditAboutDialog(UserProfile user) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to edit your profile information.',
      );
      return;
    }

    final aboutCtrl = TextEditingController(text: user.about);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int charCount = aboutCtrl.text.length;

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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'You Can Write About Your Years Of Experience, Industry, Or Skills. People Also Talk About Their Achievements Or Previous Job Experiences.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text Field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: aboutCtrl,
                      maxLines: 8,
                      minLines: 5,
                      maxLength: 2600,
                      onChanged: (val) {
                        setModalState(() {});
                      },
                      decoration: const InputDecoration(
                        hintText: 'Write your about section here...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        counterText: '', // Hide default counter
                      ),
                    ),
                  ),

                  // Counter
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$charCount/2600',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Save Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(authProvider.notifier)
                            .updateProfile({'about': aboutCtrl.text.trim()});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'About section updated successfully!'
                                    : 'Failed to update about section.',
                              ),
                              backgroundColor: ok
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
  // CUSTOM PORTFOLIO LINK DIALOG
  // -------------------------------------------------------------------
  void _showCustomPortfolioDialog(UserProfile user) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to add your portfolio link.',
      );
      return;
    }

    final urlCtrl = TextEditingController(text: user.portfolioUrl);
    final textCtrl = TextEditingController(text: user.portfolioText);

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
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Custom Portfolio Link',
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
                const SizedBox(height: 12),
                const Text(
                  'Add a link to your personal website, portfolio, GitHub, Behance, or work samples to showcase directly on your profile header.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Input 1: Website / Portfolio URL *
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(text: 'Website / Portfolio URL '),
                      TextSpan(
                        text: '*',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText:
                        'https://mywork.in or https://github.com/username',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF9333EA),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Input 2: Link Text (Optional)
                const Text(
                  'Link Text (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ex: View Portfolio ↗, Personal Website, My Work',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF9333EA),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This text will be shown on your profile header instead of the full URL.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons: Cancel & Save Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (user.portfolioUrl.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await ref
                              .read(authProvider.notifier)
                              .updateProfile({
                                'portfolio_url': '',
                                'portfolio_label': '',
                              });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Portfolio link removed successfully!'
                                      : 'Failed to remove portfolio link.',
                                ),
                                backgroundColor: ok
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        String rawUrl = urlCtrl.text.trim();
                        final linkText = textCtrl.text.trim();
                        if (rawUrl.isNotEmpty &&
                            !rawUrl.startsWith('http://') &&
                            !rawUrl.startsWith('https://')) {
                          rawUrl = 'https://$rawUrl';
                        }

                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(authProvider.notifier)
                            .updateProfile({
                              'portfolio_url': rawUrl,
                              'portfolio_label': linkText,
                            });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Custom portfolio link saved successfully!'
                                    : 'Failed to save portfolio link.',
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
                          horizontal: 22,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Link',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
  // ADD EDUCATION DIALOG
  // -------------------------------------------------------------------
  void _openAddEducationDialog([EducationItem? existingEdu]) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to add your education history.',
      );
      return;
    }

    final schoolCtrl = TextEditingController(
      text: existingEdu?.schoolName ?? '',
    );
    final degreeCtrl = TextEditingController(text: existingEdu?.degree ?? '');
    final fieldCtrl = TextEditingController(
      text: existingEdu?.fieldOfStudy ?? '',
    );
    final startCtrl = TextEditingController(text: existingEdu?.startDate ?? '');
    final endCtrl = TextEditingController(text: existingEdu?.endDate ?? '');
    final gradeCtrl = TextEditingController(text: existingEdu?.grade ?? '');
    final descCtrl = TextEditingController(
      text: existingEdu?.description ?? '',
    );

    Future<void> pickDate(TextEditingController controller) async {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1950),
        lastDate: DateTime(2100),
      );
      if (date != null) {
        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        controller.text = '${months[date.month - 1]}, ${date.year}';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.9,
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  existingEdu == null ? 'Add Education' : 'Edit Education',
                  style: const TextStyle(
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
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'School / University',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: schoolCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Indian Institute of Technology',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Degree',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: degreeCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Bachelor of Computer Science',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Field of Study',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: fieldCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Computer Science',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: startCtrl,
                                readOnly: true,
                                onTap: () => pickDate(startCtrl),
                                decoration: InputDecoration(
                                  hintText: '--------, ----',
                                  hintStyle: const TextStyle(
                                    color: Colors.black38,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Date (or expected)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: endCtrl,
                                readOnly: true,
                                onTap: () => pickDate(endCtrl),
                                decoration: InputDecoration(
                                  hintText: '--------, ----',
                                  hintStyle: const TextStyle(
                                    color: Colors.black38,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Grade',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: gradeCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: 8.5 CGPA',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe your achievements, societies, etc.',
                        hintStyle: const TextStyle(color: Colors.black38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: const BorderSide(color: Colors.black26),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (schoolCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final ok = await ref
                          .read(authProvider.notifier)
                          .addEducation(
                            id: existingEdu?.id,
                            schoolName: schoolCtrl.text,
                            degree: degreeCtrl.text,
                            fieldOfStudy: fieldCtrl.text,
                            startDate: startCtrl.text,
                            endDate: endCtrl.text,
                            grade: gradeCtrl.text,
                            description: descCtrl.text,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Education saved successfully!'
                                  : (ref.read(authProvider).error ??
                                        'Failed to save education.'),
                            ),
                            backgroundColor: ok
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
  // ADD WORK EXPERIENCE DIALOG
  // -------------------------------------------------------------------
  void _openAddExperienceDialog([ExperienceItem? existingExp]) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to add your work experience.',
      );
      return;
    }

    final titleCtrl = TextEditingController(text: existingExp?.title ?? '');
    final companyCtrl = TextEditingController(
      text: existingExp?.companyName ?? '',
    );
    final locationCtrl = TextEditingController(
      text: existingExp?.location ?? '',
    );
    final startCtrl = TextEditingController(text: existingExp?.startDate ?? '');
    final endCtrl = TextEditingController(text: existingExp?.endDate ?? '');
    final descCtrl = TextEditingController(
      text: existingExp?.description ?? '',
    );

    String selectedEmpType =
        (existingExp?.employmentType != null &&
            existingExp!.employmentType.isNotEmpty)
        ? existingExp.employmentType
        : 'Full-time';

    Widget buildLabeledField(String label, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
    }

    Future<void> pickDate(TextEditingController controller) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1950),
        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        controller.text = '${months[picked.month - 1]}, ${picked.year}';
      }
    }

    final inputDec = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingExp != null
                          ? 'Edit Experience'
                          : 'Add Experience',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        buildLabeledField(
                          'Title',
                          TextField(
                            controller: titleCtrl,
                            decoration: inputDec.copyWith(
                              hintText: 'Ex: Retail Sales Manager',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildLabeledField(
                          'Employment Type',
                          DropdownButtonFormField<String>(
                            initialValue: selectedEmpType,
                            decoration: inputDec,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items:
                                [
                                      'Full-time',
                                      'Part-time',
                                      'Self-employed',
                                      'Freelance',
                                      'Contract',
                                      'Internship',
                                    ]
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedEmpType = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildLabeledField(
                          'Company Name',
                          TextField(
                            controller: companyCtrl,
                            decoration: inputDec.copyWith(
                              hintText: 'Ex: Microsoft',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildLabeledField(
                          'Location',
                          TextField(
                            controller: locationCtrl,
                            decoration: inputDec.copyWith(
                              hintText: 'Ex: Bangalore, India',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: buildLabeledField(
                                'Start Date',
                                TextField(
                                  controller: startCtrl,
                                  readOnly: true,
                                  onTap: () => pickDate(startCtrl),
                                  decoration: inputDec.copyWith(
                                    hintText: '---------, ----',
                                    suffixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: buildLabeledField(
                                'End Date (or Present)',
                                TextField(
                                  controller: endCtrl,
                                  readOnly: true,
                                  onTap: () => pickDate(endCtrl),
                                  decoration: inputDec.copyWith(
                                    hintText: '---------, ----',
                                    suffixIcon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        buildLabeledField(
                          'Description',
                          TextField(
                            controller: descCtrl,
                            maxLines: 4,
                            decoration: inputDec.copyWith(
                              hintText: 'Describe your responsibilities and achievements.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
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
                                        employmentType: selectedEmpType,
                                        location: locationCtrl.text,
                                        startDate: startCtrl.text,
                                        endDate: endCtrl.text,
                                        description: descCtrl.text,
                                      );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Experience saved successfully!'
                                              : (ref.read(authProvider).error ??
                                                    'Failed to save experience.'),
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
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // ADD SKILL DIALOG
  // -------------------------------------------------------------------
  void _openAddSkillDialog() {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to add skills to your profile.',
      );
      return;
    }

    final skillCtrl = TextEditingController();

    final predefinedSkills = [
      'React',
      'React Native',
      'Go',
      'Golang',
      'Project Management',
      'Flutter',
      'Dart',
      'Python',
      'JavaScript',
      'TypeScript',
      'Node.js',
      'Java',
      'Spring Boot',
      'C++',
      'C#',
      '.NET',
      'PHP',
      'Laravel',
      'Swift',
      'Kotlin',
      'SQL',
      'PostgreSQL',
      'MySQL',
      'MongoDB',
      'Redis',
      'Docker',
      'Kubernetes',
      'AWS',
      'Azure',
      'GCP',
      'DevOps',
      'CI/CD',
      'Git',
      'GraphQL',
      'REST API',
      'Microservices',
      'UI/UX Design',
      'Figma',
      'HTML/CSS',
      'Tailwind CSS',
      'System Architecture',
      'Agile / Scrum',
      'Data Analysis',
      'Machine Learning',
      'Data Science',
      'Cybersecurity',
      'Digital Marketing',
      'SEO',
      'Content Writing',
      'Sales Management',
      'Business Development',
      'Customer Support',
      'Financial Analysis',
      'Accounting',
      'Operations Management',
      'Supply Chain Management',
      'Human Resources (HR)',
      'Recruitment',
      'Product Management',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final query = skillCtrl.text.trim();
            final filteredSkills = query.length >= 2
                ? predefinedSkills
                      .where(
                        (s) => s.toLowerCase().contains(query.toLowerCase()),
                      )
                      .toList()
                : <String>[];

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
                        'Add Skill',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Search for a skill to add to your profile. (Pre-defined skills only)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: skillCtrl,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ex: React, Go, Project Management...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (query.length < 2) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'Type at least 2 characters to search',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ] else if (filteredSkills.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              'No matching pre-defined skill found.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final customSkill = skillCtrl.text.trim();
                                Navigator.pop(ctx);
                                final ok = await ref
                                    .read(authProvider.notifier)
                                    .addSkill(customSkill);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Skill "$customSkill" added successfully!'
                                            : 'Failed to add skill.',
                                      ),
                                      backgroundColor: ok
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text('Add "$query" to Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filteredSkills.map((skillName) {
                            return ActionChip(
                              label: Text(skillName),
                              backgroundColor: AppColors.primaryLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 0.5,
                              ),
                              labelStyle: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final ok = await ref
                                    .read(authProvider.notifier)
                                    .addSkill(skillName);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Skill "$skillName" added successfully!'
                                            : 'Failed to add skill.',
                                      ),
                                      backgroundColor: ok
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  );
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // IMAGE & DOCUMENT PICKERS
  // -------------------------------------------------------------------

  Future<void> _pickAndUploadResumePdf() async {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to upload your resume document.',
      );
      return;
    }

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
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to verify your email address.',
      );
      return;
    }

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
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '4-Digit OTP Code',
                      hintText: '• • • •',
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
                            final otp = otpCtrl.text.trim();
                            if (otp.length != 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid 4-digit OTP code.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            setModalState(() => isVerifying = true);
                            final ok = await ref
                                .read(authProvider.notifier)
                                .verifyEmailOtp(emailCtrl.text.trim(), otp);
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
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to update your career preferences.',
      );
      return;
    }

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
                              ? 'Preferences saved on this device. Online sync is coming soon.'
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
  // REFILL WALLET CREDITS / ADD MONEY
  // -------------------------------------------------------------------
  void _showRefillWalletModal() {
    AuthGuard.openProtected(
      context,
      '/wallet/add-money',
      message: 'Please login to access your wallet.',
    );
  }

  // -------------------------------------------------------------------
  // ADD PROFILE SECTION SHEET
  // -------------------------------------------------------------------
  void _showAddSectionSheet() {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to customize your profile sections.',
      );
      return;
    }

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
    // More Actions are for signed-in users only; guests never open the sheet.
    if (!AuthGuard.isSignedIn(ref.read(authProvider))) return;

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
                onTap: () async {
                  Navigator.pop(ctx);
                  final userId = user?.id ?? '';
                  if (userId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Profile link is not available yet. Please try again.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final profileUrl = ApiConstants.publicProfileUrl(userId);
                  await Clipboard.setData(ClipboardData(text: profileUrl));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile link copied: $profileUrl'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
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
  // HERO COVER BANNER WIDGET
  // -------------------------------------------------------------------
  Widget _buildHeroBanner(UserProfile? user, int connectionsCount) {
    final coverImage = ApiConstants.resolveImageUrl(user?.coverImage ?? '');
    final profileImage = ApiConstants.resolveImageUrl(user?.profileImage ?? '');
    final hasCover =
        coverImage.isNotEmpty &&
        (coverImage.startsWith('http://') || coverImage.startsWith('https://'));
    final hasAvatar =
        profileImage.isNotEmpty &&
        (profileImage.startsWith('http://') ||
            profileImage.startsWith('https://'));
    final isAuth = ref.watch(authProvider).isAuthenticated;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
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
                      image: hasCover
                          ? DecorationImage(
                              image: NetworkImage(coverImage),
                              fit: BoxFit.cover,
                              onError: (_, _) {},
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
                            onBackgroundImageError: hasAvatar
                                ? (_, _) {}
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
                      onTap: () => AuthGuard.openProtected(context, '/network'),
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

                const SizedBox(height: 6),

                // Custom Portfolio / Website Link
                InkWell(
                  onTap: () async {
                    if (user == null) return;
                    if (user.portfolioUrl.isEmpty) {
                      _showCustomPortfolioDialog(user);
                    } else {
                      final uri = Uri.tryParse(user.portfolioUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open link: ${user.portfolioUrl}',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          size: 16,
                          color: Color(0xFF9333EA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user != null && user.portfolioUrl.isNotEmpty
                              ? (user.portfolioText.isNotEmpty
                                    ? user.portfolioText
                                    : user.portfolioUrl)
                              : '+ Add Portfolio / Website Link',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9333EA),
                          ),
                        ),
                        if (user != null && user.portfolioUrl.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showCustomPortfolioDialog(user),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Email Verification Status Banner (Dynamic from backend)
                if (user != null) ...[
                  if (!user.isEmailVerified) ...[
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
                              user.email.isNotEmpty
                                  ? 'Email Unverified: ${user.email}'
                                  : 'Email Unverified',
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
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.email.isNotEmpty
                                  ? 'Email Verified: ${user.email}'
                                  : 'Email Verified',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
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
                      // Disabled (greyed out) for guests: no More Actions.
                      onPressed: AuthGuard.isSignedIn(ref.watch(authProvider))
                          ? () => _showMoreProfileMenu(user)
                          : null,
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
    return InkWell(
      onTap: () => AuthGuard.openProtected(
        context,
        '/wallet',
        message: 'Please login to access your wallet.',
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1738), // Deep navy matching screenshot
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Wallet Credits',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Real total balance from GET /wallet/balance
                    '₹${(ref.watch(walletProvider).summary?.totalBalance ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _showRefillWalletModal,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF38232C,
                  ), // Matches screenshot dark warm brownish-red
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(
                      0xFF8A4630,
                    ), // Matches screenshot warm border
                    width: 1.2,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹ Refill Wallet',
                      style: TextStyle(
                        color: Color(
                          0xFFF97316,
                        ), // Brand Orange from screenshot
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // PUBLIC PROFILE & LANGUAGE SETTINGS CARD (media_1789974076369.png)
  // -------------------------------------------------------------------
  Widget _buildPublicProfileAndLanguageCard(UserProfile? user) {
    final publicUrl = user != null && user.id.isNotEmpty
        ? 'www.kaammilega.com/in/${user.id}'
        : 'www.kaammilega.com/in/...';
    final fullUrl = user != null && user.id.isNotEmpty
        ? 'https://www.kaammilega.com/in/${user.id}'
        : 'https://www.kaammilega.com';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Language
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Language',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'English',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: _showLanguageSelectionModal,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ),

          // Public Profile & URL
          InkWell(
            onTap: () {
              if (user != null && user.id.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: fullUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Public profile URL copied: $publicUrl'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please sign in to view your unique profile URL.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Public Profile & URL',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        publicUrl,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Profile Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                title: const Text(
                  'English (Default)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.check, color: AppColors.primary),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                title: const Text('Hindi (हिंदी)'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Language preference updated.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                    const Expanded(
                      child: Text(
                        'Open To Work',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (user != null)
                      InkWell(
                        onTap: () => _showOpenToModal(user),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
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
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                    const Expanded(
                      child: Text(
                        'Providing Services',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (user != null)
                      InkWell(
                        onTap: () => _showOpenToModal(user),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
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

    bool hasExp = user.experience.isNotEmpty;
    bool hasPhoto = user.profileImage.isNotEmpty;
    bool hasEdu = user.education.isNotEmpty;
    bool hasSkills = user.skills.length >= 3;
    bool hasAbout = user.about.isNotEmpty;
    bool hasHeadline = user.headline.isNotEmpty && user.city.isNotEmpty;
    bool hasEmail = user.isEmailVerified;

    int percentage = 0;
    if (hasExp) percentage += 15;
    if (hasPhoto) percentage += 15;
    if (hasEdu) percentage += 15;
    if (hasSkills) percentage += 15;
    if (hasAbout) percentage += 15;
    if (hasHeadline) percentage += 15;
    if (hasEmail) percentage += 10;

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
              const Expanded(
                child: Text(
                  'Profile Completeness',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$percentage% ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9333EA),
                      ),
                    ),
                    const TextSpan(
                      text: 'completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete the recommended sections below to help recruiters discover and evaluate your profile.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3E8FF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF9333EA),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SUGGESTED STEPS TO REACH 100%:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textLight,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _showCompletenessDetails = !_showCompletenessDetails;
                  });
                },
                child: Text(
                  _showCompletenessDetails
                      ? 'Hide Details ^'
                      : 'Show Details v',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9333EA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!hasExp)
                _buildCompletenessChip(
                  'Add Work Experience +',
                  _openAddExperienceDialog,
                ),
              if (!hasPhoto)
                _buildCompletenessChip(
                  'Add Profile Photo +',
                  _showAddProfilePhotoModal,
                ),
              if (!hasEdu)
                _buildCompletenessChip(
                  'Add Education +',
                  _openAddEducationDialog,
                ),
              if (!hasSkills)
                _buildCompletenessChip(
                  'Add Skills (3+) +',
                  _openAddSkillDialog,
                ),
              if (!hasAbout)
                _buildCompletenessChip(
                  'Add About Summary +',
                  () => _showEditAboutDialog(user),
                ),
              if (!hasHeadline)
                _buildCompletenessChip(
                  'Add Headline & Location +',
                  () => _openEditProfileDialog(user),
                ),
              if (!hasEmail)
                _buildCompletenessChip(
                  'Add Email Verification +',
                  () => _showEmailOtpDialog(user.email),
                ),
            ],
          ),
          if (_showCompletenessDetails) ...[
            const SizedBox(height: 20),
            const Text(
              'COMPLETENESS BREAKDOWN:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildBreakdownCard(
                  title: 'Work Experience',
                  subtitle:
                      'Add your past or current roles to highlight your career',
                  isCompleted: hasExp,
                  onTap: _openAddExperienceDialog,
                ),
                _buildBreakdownCard(
                  title: 'Profile Photo',
                  subtitle:
                      'Upload a clear profile picture to be easily recognized',
                  isCompleted: hasPhoto,
                  onTap: _showAddProfilePhotoModal,
                ),
                _buildBreakdownCard(
                  title: 'Education',
                  subtitle: 'Add your degree, college or certifications',
                  isCompleted: hasEdu,
                  onTap: _openAddEducationDialog,
                ),
                _buildBreakdownCard(
                  title: 'Skills (3+)',
                  subtitle:
                      'Add at least 3 skills (current: ${user.skills.length})',
                  isCompleted: hasSkills,
                  onTap: _openAddSkillDialog,
                ),
                _buildBreakdownCard(
                  title: 'About Summary',
                  subtitle:
                      'Write a brief professional summary of your background',
                  isCompleted: hasAbout,
                  onTap: () => _showEditAboutDialog(user),
                ),
                _buildBreakdownCard(
                  title: 'Headline & Location',
                  subtitle: 'Specify your job title/designation and city',
                  isCompleted: hasHeadline,
                  onTap: () => _openEditProfileDialog(user),
                ),
                _buildBreakdownCard(
                  title: 'Email Verification',
                  subtitle: 'Verify your registered email for direct recruiter messages',
                  isCompleted: hasEmail,
                  onTap: () => _showEmailOtpDialog(user.email),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletenessChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9D5FF)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9333EA),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required String subtitle, // kept to avoid modifying the caller signature
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isCompleted ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF1F5F9), // subtle border
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isCompleted
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              size: 16,
              color: isCompleted
                  ? const Color(0xFF10B981) // Emerald green
                  : const Color(0xFFF59E0B), // Amber orange
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFD1FAE5) // Light emerald
                    : const Color(0xFFFEF3C7), // Light amber
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isCompleted ? 'Completed' : 'Pending',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: isCompleted
                      ? const Color(0xFF047857) // Dark emerald
                      : const Color(0xFFB45309), // Dark amber
                ),
              ),
            ),
          ],
        ),
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
  /// Profile viewers & connection suggestions are not available from the
  /// backend yet. (Previously this card showed two made-up people with
  /// invented mutual-connection counts, and "Connect" sent requests to
  /// fake user IDs.)
  Widget _buildPeopleWhoViewedCard() {
    return Container(
      width: double.infinity,
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
                onPressed: () => AuthGuard.openProtected(context, '/network'),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          const SizedBox(height: 4),
          const Text(
            'Profile viewers and people suggestions are coming soon. '
            'Meanwhile, grow your network from the Network page.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
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
                      'Career, interview & skill mentors',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                // Opens the real Experts directory (GET /mentorships).
                // Previously this only showed a placeholder message.
                onPressed: () => context.push('/experts'),
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
                  'Find Mentors',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // ADD PROJECT DIALOG & WIDGET (web-matched media_1789560057895.png)
  // -------------------------------------------------------------------
  void _openAddProjectDialog([ProjectItem? existingProject]) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In Required',
        message: 'Please sign in to add projects to your profile.',
      );
      return;
    }

    final titleCtrl = TextEditingController(text: existingProject?.title ?? '');
    final associatedWithCtrl = TextEditingController(
      text: existingProject?.associatedWith ?? '',
    );
    final linkCtrl = TextEditingController(text: existingProject?.link ?? '');
    final descCtrl = TextEditingController(
      text: existingProject?.description ?? '',
    );
    final skillsCtrl = TextEditingController(
      text: existingProject?.skills ?? '',
    );

    String startMonth = 'Month';
    String startYear = 'Year';
    String endMonth = 'Month';
    String endYear = 'Year';

    final monthsList = [
      'Month',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final currentYear = DateTime.now().year;
    final yearsList = [
      'Year',
      for (int y = currentYear + 2; y >= 1980; y--) y.toString(),
    ];

    if (existingProject != null) {
      final startParts = existingProject.startDate.split(' ');
      if (startParts.isNotEmpty) {
        final matchM = monthsList.firstWhere(
          (m) => m.toLowerCase().startsWith(startParts[0].toLowerCase()),
          orElse: () => 'Month',
        );
        startMonth = matchM;
        if (startParts.length > 1) {
          startYear = startParts[1];
        }
      }
      final endParts = existingProject.endDate.split(' ');
      if (endParts.isNotEmpty) {
        final matchM = monthsList.firstWhere(
          (m) => m.toLowerCase().startsWith(endParts[0].toLowerCase()),
          orElse: () => 'Month',
        );
        endMonth = matchM;
        if (endParts.length > 1) {
          endYear = endParts[1];
        }
      }
    }

    bool isCurrentlyWorking = existingProject?.isCurrentlyWorking ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isTitleNotEmpty = titleCtrl.text.trim().isNotEmpty;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingProject == null ? 'Add Project' : 'Edit Project',
                      style: const TextStyle(
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
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Project / Work Name *
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            children: [
                              TextSpan(text: 'Project / Work Name '),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleCtrl,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Ex: KaamMilega Mobile App, Modular Kitchen Woodwork, Brand Camp',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Associated With (Optional)
                        const Text(
                          'Associated With (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: associatedWithCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ex: Freelance, TCS, Self-employed, or Client Name',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Start Date & End Date Dropdown Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Start Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: startMonth,
                                              isExpanded: true,
                                              icon: const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Color(0xFF64748B),
                                                size: 20,
                                              ),
                                              items: monthsList.map((m) {
                                                final isPlaceholder =
                                                    m == 'Month';
                                                return DropdownMenuItem(
                                                  value: m,
                                                  child: Text(
                                                    m.length > 5 && m != 'Month'
                                                        ? m.substring(0, 3)
                                                        : m,
                                                    style: TextStyle(
                                                      color: isPlaceholder
                                                          ? const Color(
                                                              0xFF94A3B8,
                                                            )
                                                          : const Color(
                                                              0xFF1E293B,
                                                            ),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setModalState(
                                                    () => startMonth = val,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: startYear,
                                              isExpanded: true,
                                              icon: const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Color(0xFF64748B),
                                                size: 20,
                                              ),
                                              items: yearsList.map((y) {
                                                final isPlaceholder =
                                                    y == 'Year';
                                                return DropdownMenuItem(
                                                  value: y,
                                                  child: Text(
                                                    y,
                                                    style: TextStyle(
                                                      color: isPlaceholder
                                                          ? const Color(
                                                              0xFF94A3B8,
                                                            )
                                                          : const Color(
                                                              0xFF1E293B,
                                                            ),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setModalState(
                                                    () => startYear = val,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // End Date
                            Expanded(
                              child: Opacity(
                                opacity: isCurrentlyWorking ? 0.4 : 1.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'End Date',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: endMonth,
                                                isExpanded: true,
                                                icon: const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Color(0xFF64748B),
                                                  size: 20,
                                                ),
                                                items: monthsList.map((m) {
                                                  final isPlaceholder =
                                                      m == 'Month';
                                                  return DropdownMenuItem(
                                                    value: m,
                                                    child: Text(
                                                      m.length > 5 &&
                                                              m != 'Month'
                                                          ? m.substring(0, 3)
                                                          : m,
                                                      style: TextStyle(
                                                        color: isPlaceholder
                                                            ? const Color(
                                                                0xFF94A3B8,
                                                              )
                                                            : const Color(
                                                                0xFF1E293B,
                                                              ),
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: isCurrentlyWorking
                                                    ? null
                                                    : (val) {
                                                        if (val != null) {
                                                          setModalState(
                                                            () =>
                                                                endMonth = val,
                                                          );
                                                        }
                                                      },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: endYear,
                                                isExpanded: true,
                                                icon: const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Color(0xFF64748B),
                                                  size: 20,
                                                ),
                                                items: yearsList.map((y) {
                                                  final isPlaceholder =
                                                      y == 'Year';
                                                  return DropdownMenuItem(
                                                    value: y,
                                                    child: Text(
                                                      y,
                                                      style: TextStyle(
                                                        color: isPlaceholder
                                                            ? const Color(
                                                                0xFF94A3B8,
                                                              )
                                                            : const Color(
                                                                0xFF1E293B,
                                                              ),
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: isCurrentlyWorking
                                                    ? null
                                                    : (val) {
                                                        if (val != null) {
                                                          setModalState(
                                                            () => endYear = val,
                                                          );
                                                        }
                                                      },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 4. Currently working checkbox
                        InkWell(
                          onTap: () {
                            setModalState(() {
                              isCurrentlyWorking = !isCurrentlyWorking;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: isCurrentlyWorking,
                                    activeColor: const Color(0xFF9333EA),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setModalState(() {
                                        isCurrentlyWorking = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'I am currently working on this project',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 5. Project URL (Optional)
                        const Text(
                          'Project URL (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: linkCtrl,
                          decoration: InputDecoration(
                            hintText: 'https://example.com, GitHub, Google Drive, or Demo link',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 6. Description
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: descCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Describe your role, responsibilities, tools used, or client results...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 7. Skills Used (Comma separated, optional)
                        const Text(
                          'Skills Used (Comma separated, optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: skillsCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ex: React, Go, MongoDB, Carpentry, Customer Handling',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF9333EA),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Action buttons: Cancel & Save Project
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (existingProject != null &&
                        existingProject.id.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await ref
                              .read(authProvider.notifier)
                              .deleteProject(existingProject.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Project deleted.'
                                      : (ref.read(authProvider).error ??
                                            'Failed to delete project.'),
                                ),
                                backgroundColor: ok
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a project name'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        final formattedStartDate =
                            (startMonth != 'Month' || startYear != 'Year')
                            ? '${startMonth != "Month" ? startMonth : ""} ${startYear != "Year" ? startYear : ""}'
                                  .trim()
                            : '';
                        final formattedEndDate = isCurrentlyWorking
                            ? 'Present'
                            : ((endMonth != 'Month' || endYear != 'Year')
                                  ? '${endMonth != "Month" ? endMonth : ""} ${endYear != "Year" ? endYear : ""}'
                                        .trim()
                                  : '');

                        final ok = await ref
                            .read(authProvider.notifier)
                            .addProject(
                              id: existingProject?.id,
                              title: title,
                              associatedWith: associatedWithCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              link: linkCtrl.text.trim(),
                              startDate: formattedStartDate,
                              endDate: formattedEndDate,
                              skills: skillsCtrl.text.trim(),
                              isCurrentlyWorking: isCurrentlyWorking,
                            );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? (existingProject == null
                                          ? 'Project added successfully!'
                                          : 'Project updated successfully!')
                                    : (ref.read(authProvider).error ??
                                          'Failed to save project.'),
                              ),
                              backgroundColor: ok
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTitleNotEmpty
                            ? const Color(0xFF9333EA)
                            : const Color(0xFFCBD5E1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        existingProject == null
                            ? 'Save Project'
                            : 'Update Project',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectsCard(UserProfile? user) {
    final projects = user?.projects ?? [];
    final hasProjects = projects.isNotEmpty;

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
                'Projects',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openAddProjectDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Project',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9333EA),
                  side: const BorderSide(color: Color(0xFF9333EA)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Showcase your practical work, assignments, or client projects',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (!hasProjects)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Showcase your projects and assignments',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Candidates who add projects, practical tasks, or work samples are more likely to be contacted by recruiters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _openAddProjectDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '+ Add Your First Project',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: projects.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.folder_special_rounded,
                            color: Color(0xFF9333EA),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (p.associatedWith.isNotEmpty)
                                          Text(
                                            p.associatedWith,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: Color(0xFF9333EA),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _openAddProjectDialog(p),
                                  ),
                                ],
                              ),
                              if (p.startDate.isNotEmpty ||
                                  p.endDate.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${p.startDate} ${p.endDate.isNotEmpty ? "- ${p.endDate}" : ""}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (p.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  p.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (p.skills.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: p.skills
                                      .split(',')
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .map(
                                        (skill) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3E8FF),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            skill,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF9333EA),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              if (p.link.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final uri = Uri.tryParse(p.link);
                                    if (uri != null &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.link_rounded,
                                        size: 14,
                                        color: Color(0xFF9333EA),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          p.link,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9333EA),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // COMPANIES TO FOLLOW CARD (media_1789560057892.png)
  // -------------------------------------------------------------------
  Widget _buildCompaniesToFollowCard() {
    final companies = [
      {
        'id': 'c1',
        'name': 'Technova',
        'category': 'Software Solutions • IT Services',
        'logo': 'TN',
      },
      {
        'id': 'c2',
        'name': 'Infosys Digital',
        'category': 'IT Services & Consulting',
        'logo': 'INF',
      },
      {
        'id': 'c3',
        'name': 'TCS Global',
        'category': 'Enterprise Solutions & Tech',
        'logo': 'TCS',
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
          const Text(
            'Companies',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 16),
          StatefulBuilder(
            builder: (ctx, setCompState) {
              return Column(
                children: companies.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c['logo']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                c['category']!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (!ref.read(authProvider).isAuthenticated) {
                              showAuthPromptDialog(
                                context,
                                title: 'Sign In Required',
                                message: 'Please sign in to follow companies and receive job updates.',
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'You are now following ${c['name']}',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9333EA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
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
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // JOBS BASED ON YOUR PROFILE CARD (media_1789560057906.png)
  // -------------------------------------------------------------------
  Widget _buildJobsBasedOnProfileCard() {
    final jobCategories = [
      {'title': 'Fintech', 'hiring': '1.4K+ Are Actively Hiring'},
      {'title': 'Internet', 'hiring': '1.4K+ Are Actively Hiring'},
      {'title': 'Fortune 500', 'hiring': '1.4K+ Are Actively Hiring'},
      {'title': 'MNCs', 'hiring': '2.1K+ Are Actively Hiring'},
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
          const Text(
            'Jobs Based On Your Profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: jobCategories.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final cat = jobCategories[idx];
                return InkWell(
                  onTap: () => context.go('/jobs'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat['title']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.textLight,
                            ),
                          ],
                        ),
                        Text(
                          cat['hiring']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            4,
                            (i) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.grey.shade300,
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
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/jobs'),
              child: const Text(
                'See All Jobs',
                style: TextStyle(
                  color: Color(0xFF9333EA),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// There is no real KaamMilega helpline number yet. (Previously this
  /// dialled a placeholder number, 1800 123 456.)
  void _callHR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Phone support is coming soon. Please use Chat to contact recruiters.',
        ),
      ),
    );
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
      ),
      body: authState.isLoading
          ? const ShimmerLoadingList(count: 3)
          : RefreshIndicator(
              onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Cover & Header Card (Edge-to-edge: 0 horizontal margin)
                    _buildHeroBanner(user, connectionsCount),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Twin Cards: Open To Work & Providing Services (media_1789560057886.png)
                          _buildTwinOpenToCards(user),

                          const SizedBox(height: 16),

                          // 3. Profile Strength & Completeness Breakdown Card (media_1789560057886.png)
                          _buildProfileCompletenessCard(user),

                          const SizedBox(height: 16),

                          // ("Free Now for Gigs" card removed on request.)
                          // 5. Analytics Card - Private To You (media_1789560057892.png)
                          _buildAnalyticsCard(user),

                          const SizedBox(height: 16),

                          // 6. About Card (media_1789560057892.png)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'About',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (user != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () =>
                                            _showEditAboutDialog(user),
                                      ),
                                  ],
                                ),
                                const Divider(height: 12),
                                Text(
                                  user != null && user.about.isNotEmpty
                                      ? user.about
                                      : 'Add a summary to highlight your personality and work history.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: user != null && user.about.isNotEmpty
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 7. Jobs Based On Your Profile (media_1789560057906.png)
                          _buildJobsBasedOnProfileCard(),

                          const SizedBox(height: 16),

                          // 8. Work Experience List Card (media_1789560057906.png)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Experience',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            color: AppColors.primary,
                                            size: 20,
                                          ),
                                          onPressed: _openAddExperienceDialog,
                                        ),
                                        // Edit button removed: the backend can only
                                        // ADD experience (no update/delete endpoint yet).
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                if (user == null || user.experience.isEmpty)
                                  const Text(
                                    'No experience added yet.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Column(
                                    children: user.experience.map((exp) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${exp.companyName} • ${exp.location}'
                                                        .trim(),
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (exp.startDate.isNotEmpty)
                                                    Text(
                                                      '${exp.startDate} - ${exp.endDate}',
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.textLight,
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

                          // 9. Education History Card (media_1789560057895.png)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Education',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            color: AppColors.primary,
                                            size: 20,
                                          ),
                                          onPressed: _openAddEducationDialog,
                                        ),
                                        // Edit button removed: the backend can only
                                        // ADD education (no update/delete endpoint yet).
                                        // Editing re-sent the entry and created a duplicate.
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                if (user == null || user.education.isEmpty)
                                  const Text(
                                    'No education details added yet.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Column(
                                    children: user.education.map((edu) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${edu.degree} ${edu.fieldOfStudy}'
                                                        .trim(),
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (edu.startDate.isNotEmpty)
                                                    Text(
                                                      '${edu.startDate} - ${edu.endDate}',
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.textLight,
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

                          // 10. Projects & Assignments Card (media_1789560057895.png)
                          _buildProjectsCard(user),

                          const SizedBox(height: 16),

                          // 11. Candidate Skills Tagging Card
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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

                          // 12. Companies To Follow Card (media_1789560057892.png)
                          _buildCompaniesToFollowCard(),

                          const SizedBox(height: 16),

                          // 13. People Who Viewed / Network Suggestions Card (media_1789560057886.png)
                          _buildPeopleWhoViewedCard(),

                          const SizedBox(height: 16),

                          // 14. Our Experts Preview Card (media_1789560057886.png)
                          _buildOurExpertsCard(),

                          const SizedBox(height: 16),

                          // 15. Personal Info Summary Card
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text(
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 16. Wallet Credits Card
                          _buildWalletCreditsCard(user),

                          const SizedBox(height: 16),

                          // 17. Public Profile & Language Settings Card (media_1789974076369.png)
                          _buildPublicProfileAndLanguageCard(user),

                          const SizedBox(height: 16),

                          // 18. Resume PDF Card
                          _buildResumeCard(user),

                          if (authState.isAuthenticated || user != null) ...[
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _showLogoutConfirmationDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(
                                  color: Color(0xFFFCA5A5),
                                  width: 1.5,
                                ),
                                backgroundColor: const Color(0xFFFEF2F2),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.logout_rounded,
                                size: 20,
                                color: Color(0xFFDC2626),
                              ),
                              label: const Text(
                                'Log Out',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 24),
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
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
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

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your KaamMilega account?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
