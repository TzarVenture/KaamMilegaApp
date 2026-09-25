import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../cities/presentation/city_selector_sheet.dart';
import '../providers/auth_provider.dart';

/// Registration step for a signed-in account that is not registered yet:
/// a new phone number after OTP, or a new email sign-up.
///
/// Completes the SAME account with POST /user/register (it never creates a
/// second account). Back / Cancel and "Use a different account" both log
/// out, so a half-registered session is never kept.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  // Choices shown by the KaamMilega website registration form
  // (km-frontend/src/app/register/page.tsx). The backend stores them as
  // plain text, so the same values are sent.
  static const List<String> genders = ['Male', 'Female', 'Other'];
  static const List<String> educationLevels = [
    'Below 10th Pass',
    '10th Pass',
    '12th Pass',
    'Diploma',
    'Graduate',
    'Post Graduate',
  ];
  static const List<String> workExperienceTypes = [
    'I am a Fresher',
    'I am Experienced',
  ];
  static const List<String> jobCategories = [
    'Delivery Boy / Executive',
    'Driver / Chauffeur',
    'Warehouse / Logistics Helper',
    'Manufacturing / Factory Staff',
    'Housekeeping / Office Peon',
    'Security Guard',
    'Painter / Artisan',
    'Construction Labour / Helper',
    'Retail Sales Executive',
    'Telecaller / BPO',
  ];
  static const List<String> experienceDurations = [
    'Fresher',
    '1-6 Months',
    '1 Year',
    '2 Years',
    '3+ Years',
  ];

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  late final TextEditingController _nameController;
  String? _gender;
  String? _education;
  String? _workExperience;
  String? _city;
  final List<String> _selectedJobs = [];
  String? _experienceDuration;
  bool _isSubmitting = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name.trim() ?? '');
    // Keep anything the account already has (e.g. partly filled earlier).
    _gender = _preset(user?.gender, CompleteProfileScreen.genders);
    _education = _preset(
      user?.educationLevel,
      CompleteProfileScreen.educationLevels,
    );
    _workExperience = _preset(
      user?.workExperience,
      CompleteProfileScreen.workExperienceTypes,
    );
    final city = user?.city.trim() ?? '';
    _city = city.isNotEmpty ? city : null;
    _selectedJobs.addAll(
      (user?.jobCategories ?? const <String>[]).where(
        CompleteProfileScreen.jobCategories.contains,
      ),
    );
    _experienceDuration = _preset(
      user?.experienceDetail,
      CompleteProfileScreen.experienceDurations,
    );
  }

  static String? _preset(String? value, List<String> options) {
    final v = value?.trim() ?? '';
    return options.contains(v) ? v : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validate() {
    if (_nameController.text.trim().length < 2) {
      return 'Please enter your full name.';
    }
    if (_gender == null) return 'Please select your gender.';
    if (_education == null) return 'Please select your education level.';
    if (_workExperience == null) {
      return 'Please tell us if you are a fresher or experienced.';
    }
    if (_city == null) return 'Please select your city.';
    if (_selectedJobs.isEmpty) {
      return 'Please select at least one job role category.';
    }
    if (_experienceDuration == null) {
      return 'Please select your total work experience.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isLeaving) return;
    FocusScope.of(context).unfocus();
    final problem = _validate();
    if (problem != null) {
      _showSnackBar(problem, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    // Kept for after the await: the router may leave this screen as soon as
    // the account is registered, and `ref` cannot be used once disposed.
    final container = ProviderScope.containerOf(context, listen: false);
    final ok = await container
        .read(authProvider.notifier)
        .completeRegistration(
          name: _nameController.text.trim(),
          gender: _gender!,
          educationLevel: _education!,
          workExperience: _workExperience!,
          city: _city!,
          jobCategories: List<String>.from(_selectedJobs),
          experienceDetail: _experienceDuration!,
        );
    final auth = container.read(authProvider);
    final registered = ok && !auth.needsProfileCompletion;
    // The screen the user wanted before signing in, or Home. Taken even if
    // the router already moved on after the state change.
    final target = registered ? AuthGuard.takePendingPath() : null;
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      _showSnackBar(
        auth.error ?? 'Could not complete registration. Please try again.',
        isError: true,
      );
      return;
    }
    if (!registered) {
      // Server answered but did not mark the account registered.
      _showSnackBar(
        'Registration could not be confirmed. Please try again.',
        isError: true,
      );
      return;
    }

    final name = auth.user?.name.trim() ?? '';
    _showSnackBar(
      name.isNotEmpty
          ? 'Welcome to KaamMilega, $name!'
          : 'Welcome to KaamMilega!',
    );
    context.go(target!);
  }

  /// Back / Cancel and "Use a different account": confirm, then log out
  /// (clears the saved token and cached profile) and return to Login.
  Future<void> _leaveRegistration({required bool differentAccount}) async {
    if (_isSubmitting || _isLeaving) return;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          differentAccount
              ? 'Use a different account?'
              : 'Cancel registration?',
        ),
        content: Text(
          differentAccount
              ? 'You will be signed out of this unfinished account so you can '
                    'sign in with another phone number or email.'
              : 'Your registration is not finished. You will be signed out '
                    'and taken back to Login. You can sign in again later to '
                    'complete it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(differentAccount ? 'Sign out' : 'Cancel registration'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLeaving = true);
    await ref.read(authProvider.notifier).logout();
    AuthGuard.takePendingPath(); // forget any screen remembered for login
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _pickCity() async {
    await CitySelectorSheet.show(
      context,
      currentCity: _city ?? '',
      onSelected: (city) {
        final value = city.trim();
        // "All" is a filter option of the shared sheet, not a city.
        if (value.isEmpty || value.toLowerCase() == 'all') {
          _showSnackBar('Please choose your city.', isError: true);
          return;
        }
        setState(() => _city = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final email = user?.email.trim() ?? '';
    final busy = _isSubmitting || _isLeaving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveRegistration(differentAccount: false);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: busy
                ? null
                : () => _leaveRegistration(differentAccount: false),
          ),
          title: const Text(
            'Complete your profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'A few details so recruiters can find you. This finishes '
                      'your KaamMilega registration.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        text: user?.isEmailVerified == true
                            ? '$email (verified)'
                            : email,
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _SectionLabel('Full name'),
                    AppTextField(
                      controller: _nameController,
                      hintText: 'Enter your full name',
                      keyboardType: TextInputType.name,
                      enabled: !busy,
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Gender'),
                    _SingleChoice(
                      options: CompleteProfileScreen.genders,
                      selected: _gender,
                      enabled: !busy,
                      onSelected: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Education level'),
                    _SingleChoice(
                      options: CompleteProfileScreen.educationLevels,
                      selected: _education,
                      enabled: !busy,
                      onSelected: (v) => setState(() => _education = v),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Work experience'),
                    _SingleChoice(
                      options: CompleteProfileScreen.workExperienceTypes,
                      selected: _workExperience,
                      enabled: !busy,
                      onSelected: (v) => setState(() => _workExperience = v),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('City'),
                    _CityField(city: _city, onTap: busy ? null : _pickCity),
                    const SizedBox(height: 20),
                    const _SectionLabel('Job roles you are looking for'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CompleteProfileScreen.jobCategories.map((job) {
                        final selected = _selectedJobs.contains(job);
                        return FilterChip(
                          label: Text(job),
                          selected: selected,
                          onSelected: busy
                              ? null
                              : (on) => setState(() {
                                  if (on) {
                                    _selectedJobs.add(job);
                                  } else {
                                    _selectedJobs.remove(job);
                                  }
                                }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Total work experience'),
                    _SingleChoice(
                      options: CompleteProfileScreen.experienceDurations,
                      selected: _experienceDuration,
                      enabled: !busy,
                      onSelected: (v) =>
                          setState(() => _experienceDuration = v),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      text: 'Complete registration',
                      isLoading: _isSubmitting,
                      onPressed: busy ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _leaveRegistration(differentAccount: true),
                      child: const Text('Use a different account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SingleChoice extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _SingleChoice({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return ChoiceChip(
          label: Text(option),
          selected: selected == option,
          onSelected: enabled ? (_) => onSelected(option) : null,
        );
      }).toList(),
    );
  }
}

class _CityField extends StatelessWidget {
  final String? city;
  final VoidCallback? onTap;

  const _CityField({required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasCity = city != null && city!.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasCity ? city! : 'Select your city',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasCity
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
