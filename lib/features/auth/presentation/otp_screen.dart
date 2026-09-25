import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
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
  bool _isResending = false;

  /// Inline error under the boxes (visual only; set when verification fails).
  String? _otpError;

  /// Increments on each failed verification to play a short shake.
  int _errorShakeCount = 0;

  @override
  void initState() {
    super.initState();
    // Rebuild on focus changes so the focused box can be highlighted.
    for (final node in _focusNodes) {
      node.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.removeListener(_onFocusChanged);
    }
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    // One verification at a time (the 4th digit and the button both trigger).
    if (_isLoading) return;

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

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Verification failed (wrong / expired OTP, network...): stay here, show
    // why and let the user type the code again. Never treated as a new user.
    if (result == null) {
      _clearOtp();
      setState(() {
        _otpError =
            ref.read(authProvider).error ??
            'Could not verify OTP. Please try again.';
        _errorShakeCount++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authProvider).error ??
                'Could not verify OTP. Please try again.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // OTP correct. The backend's is_registered decides the next screen:
    // false means this number has no completed account yet, so the same
    // account is completed on Complete Profile (POST /user/register). No
    // second account is created. (The router also enforces this.)
    if (!ref.read(authProvider).needsProfileCompletion) {
      final name = result.user?.name.trim() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            name.isNotEmpty ? 'Welcome back, $name!' : 'Welcome back!',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      // Return to the screen the user wanted before login (or Home)
      context.go(AuthGuard.takePendingPath());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone verified. Please complete your profile to finish registration.',
          ),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(AuthGuard.completeProfilePath);
    }
  }

  /// Empties the 4 OTP boxes and puts the cursor back in the first one.
  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  Future<void> _resendOtp() async {
    if (_isResending || _isLoading) return;
    setState(() => _isResending = true);

    final sent = await ref.read(authProvider.notifier).sendOtp(widget.phone);

    if (!mounted) return;
    setState(() {
      _isResending = false;
      if (sent) _otpError = null; // fresh code: clear the old error look
    });
    if (sent) _clearOtp();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'A new OTP has been sent!'
              : (ref.read(authProvider).error ??
                    'Could not send OTP. Please try again.'),
        ),
        backgroundColor: sent ? null : AppColors.error,
      ),
    );
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Verify Phone', style: AppTextStyles.heading1),
                const SizedBox(height: 8),
                Text(
                  'Enter the 4-digit code sent to +91 ${widget.phone.isNotEmpty ? widget.phone : "XXXXXXXXXX"}',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 36),
                // 4 OTP boxes: responsive, animated focus / filled / error look.
                _ShakeOnError(
                  trigger: _errorShakeCount,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final focused = _focusNodes[index].hasFocus;
                      final filled = _controllers[index].text.isNotEmpty;
                      final hasError = _otpError != null;
                      return Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 64),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  color: hasError
                                      ? const Color(0xFFFEF2F2)
                                      : filled
                                      ? AppColors.primaryLight
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: hasError
                                        ? AppColors.error
                                        : focused
                                        ? AppColors.primary
                                        : filled
                                        ? AppColors.primary.withValues(
                                            alpha: 0.35,
                                          )
                                        : AppColors.border,
                                    width: focused || hasError ? 2 : 1.2,
                                  ),
                                  boxShadow: focused
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  cursorColor: AppColors.primary,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    filled: false,
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onChanged: (val) {
                                    // Visual only: refresh box look, clear the
                                    // inline error once the user edits again.
                                    setState(() => _otpError = null);
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
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Inline error under the boxes (same message as the snackbar).
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _otpError == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _otpError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Verify & Continue',
                  isLoading: _isLoading,
                  onPressed: _verifyOtp,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive code? ",
                        style: AppTextStyles.bodySecondary,
                      ),
                      TextButton(
                        onPressed: _isResending || _isLoading
                            ? null
                            : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Text(
                                'Resend',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// Short, subtle horizontal shake played each time [trigger] increases
/// (a wrong code). Nothing happens on first build.
class _ShakeOnError extends StatelessWidget {
  const _ShakeOnError({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (trigger == 0 || MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      child: child,
      builder: (context, t, child) {
        final dx = math.sin(t * math.pi * 4) * 6 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
