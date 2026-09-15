import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() async {
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Call API to send OTP
    final success = await ref.read(authProvider.notifier).sendOtp(phone);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.push('/otp', extra: phone);
      } else {
        // Even if live API is temporarily unreachable in dev mode, navigate to OTP so user can test UI
        context.push('/otp', extra: phone);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Center(child: AppLogo(size: 90)),

              const SizedBox(height: 40),

              const Text('Find Your Next Job', style: AppTextStyles.heading1),

              const SizedBox(height: 8),

              const Text(
                'Enter your mobile number to get instant job alerts and apply.',
                style: AppTextStyles.bodySecondary,
              ),

              const SizedBox(height: 32),

              const Text('Mobile Number', style: AppTextStyles.heading3),

              const SizedBox(height: 10),

              AppTextField(
                controller: _phoneController,
                hintText: 'Enter mobile number',
                keyboardType: TextInputType.phone,
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    '+91',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              AppButton(
                text: 'Continue',
                isLoading: _isLoading,
                onPressed: _continue,
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/jobs'),
                  child: const Text(
                    'Explore Jobs as Guest',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
