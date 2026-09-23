import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../app/auth_guard.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    final otp = _controllers.map((e) => e.text).join();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 4-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref
        .read(authProvider.notifier)
        .verifyOtp(widget.phone, otp);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isRegistered &&
          result.user != null &&
          result.user!.name.isNotEmpty &&
          result.user!.name != 'Candidate') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${result.user!.name}!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        // Return to the screen the user wanted before login (or Home)
        context.go(AuthGuard.takePendingPath());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No registered account found for this number. Please create an account first.',
            ),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/register');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Verify Phone', style: AppTextStyles.heading1),
              const SizedBox(height: 8),
              Text(
                'Enter the 4-digit code sent to +91 ${widget.phone.isNotEmpty ? widget.phone : "XXXXXXXXXX"}',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (index == 3 && val.isNotEmpty) {
                          _verifyOtp();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Verify & Continue',
                isLoading: _isLoading,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive code? ",
                      style: AppTextStyles.bodySecondary,
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).sendOtp(widget.phone);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('A new OTP has been sent!'),
                          ),
                        );
                      },
                      child: const Text(
                        'Resend',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
