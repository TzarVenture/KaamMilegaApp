import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

/// Candidate Registration / Onboarding Screen
/// Matching the jobseeker onboarding flow from https://kaammilega.com/register
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _expDetailController = TextEditingController();

  String _gender = 'Male';
  String _educationLevel = '12th Pass';
  String _workExperience = 'Fresher';
  final Set<String> _selectedCategories = {'Delivery Executive'};
  bool _isLoading = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  final List<String> _educationOptions = [
    'Below 10th',
    '10th Pass',
    '12th Pass',
    'Diploma',
    'Graduate',
    'Post Graduate',
  ];

  final List<String> _experienceTypeOptions = [
    'Fresher',
    'Experienced',
  ];

  final List<String> _popularCities = [
    'Delhi',
    'Mumbai',
    'Bengaluru',
    'Pune',
    'Hyderabad',
    'Noida',
    'Gurugram',
    'Jaipur',
    'Ahmedabad',
    'Kolkata',
  ];

  final List<String> _jobCategories = [
    'Delivery Executive',
    'Driver',
    'Warehouse / Helper',
    'Security Guard',
    'Cook / Chef',
    'Housekeeping / Peon',
    'Telecaller / BPO',
    'Retail / Sales',
    'Back Office / Computer',
    'Electrician / Technician',
    'Hotel & Restaurant Staff',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      if (user.name.isNotEmpty && user.name != 'Candidate') {
        _nameController.text = user.name;
      }
      if (user.email.isNotEmpty) {
        _emailController.text = user.email;
      }
      if (user.city.isNotEmpty) {
        _cityController.text = user.city;
      } else {
        _cityController.text = 'Delhi';
      }
    } else {
      _cityController.text = 'Delhi';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _expDetailController.dispose();
    super.dispose();
  }

  void _submit() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter your city')),
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one job category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).registerCandidate(
          name: name,
          gender: _gender,
          educationLevel: _educationLevel,
          workExperience: _workExperience,
          city: city,
          jobCategories: _selectedCategories.toList(),
          experienceDetail: _expDetailController.text.trim(),
          email: _emailController.text.trim(),
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile registered successfully! Welcome to KaamMilega.'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/home');
      } else {
        // Fallback navigation in demo/dev mode
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Candidate Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B1641), Color(0xFF6B2D7B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Setup Your Jobseeker Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '100% Free • Direct Recruiter Calls • 0 Fees',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Full Name
                const Text('Full Name *', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _nameController,
                  hintText: 'e.g. Rahul Sharma',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 20),

                // 2. Gender
                const Text('Gender *', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _genderOptions.map((g) {
                    final isSelected = _gender == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _gender = g);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 3. Education Level
                const Text('Highest Education *', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _educationOptions.map((edu) {
                    final isSelected = _educationLevel == edu;
                    return ChoiceChip(
                      label: Text(edu),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _educationLevel = edu);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 4. Work Experience Type
                const Text('Work Experience *', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                Row(
                  children: _experienceTypeOptions.map((exp) {
                    final isSelected = _workExperience == exp;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _workExperience = exp),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected ? AppColors.primaryLight : Colors.white,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            exp,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 5. Preferred City
                const Text('Preferred City to Work in *', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _cityController,
                  hintText: 'e.g. Delhi, Mumbai, Pune',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _popularCities.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(c),
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () => setState(() => _cityController.text = c),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // 6. Target Job Roles / Categories
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Interested Job Roles *', style: AppTextStyles.heading3),
                    Text(
                      '${_selectedCategories.length} selected',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select the types of jobs you are looking for:',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _jobCategories.map((cat) {
                    final isSelected = _selectedCategories.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(cat);
                          } else {
                            if (_selectedCategories.length > 1) {
                              _selectedCategories.remove(cat);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 7. Summary / Experience Details
                const Text('Past Experience / Skills (Optional)', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _expDetailController,
                  hintText: 'e.g. 1 year delivery experience with 2-wheeler, valid driving license',
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // 8. Email (Optional)
                const Text('Email Address (Optional)', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _emailController,
                  hintText: 'e.g. rahul.sharma@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 32),

                // Complete Button
                AppButton(
                  text: 'Complete Profile & Find Jobs',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
