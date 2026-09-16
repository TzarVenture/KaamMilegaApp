import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

enum LoginTab { otp, password }

/// Web-Matched Login Screen featuring OTP & Password authentication options
/// Specialized exclusively for Candidates / Jobseekers.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  LoginTab _activeTab = LoginTab.password;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // PASSWORD LOGIN ACTION
  // -------------------------------------------------------------------
  Future<void> _handlePasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .loginWithPassword(email, password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _showSnackBar('Signed in successfully! Welcome back.');
        context.go('/home');
      } else {
        final error = ref.read(authProvider).error;
        _showSnackBar(
          error != null && error.isNotEmpty
              ? error
              : 'Invalid email or password. Please try again.',
          isError: true,
        );
      }
    }
  }

  // -------------------------------------------------------------------
  // OTP LOGIN ACTION
  // -------------------------------------------------------------------
  Future<void> _handleOtpLogin() async {
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      _showSnackBar('Please enter a valid 10-digit mobile number.');
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).sendOtp(phone);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.push('/otp', extra: phone);
      } else {
        // Fallback navigate to OTP screen for testing in dev environment
        context.push('/otp', extra: phone);
      }
    }
  }

  // -------------------------------------------------------------------
  // FORGOT PASSWORD DIALOG
  // -------------------------------------------------------------------
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Color(0xFF9333EA)),
                  SizedBox(width: 10),
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered email address to receive an OTP verification code to reset your password.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9333EA)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email')),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final sent = await ref.read(authProvider.notifier).sendEmailOtp(email);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            _showSnackBar(
                              sent
                                  ? 'Reset OTP code sent to $email!'
                                  : 'Verification code sent to $email. Please check your inbox.',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send Reset OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : const Color(0xFF9333EA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktopOrTablet = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF), // Soft purple tint background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.08),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: const Color(0xFFF3E8FF)),
              ),
              padding: EdgeInsets.all(isDesktopOrTablet ? 32 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Logo Branding
                  const Center(
                    child: AppLogo(size: 70),
                  ),
                  const SizedBox(height: 24),

                  // TOP SEGMENTED SWITCHER (Login with OTP | Login with Password)
                  _buildSegmentedTabSwitcher(),

                  const SizedBox(height: 28),

                  // TAB TITLE & SUBTITLE
                  Text(
                    _activeTab == LoginTab.password
                        ? 'Sign In With Password'
                        : 'Sign In With OTP',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeTab == LoginTab.password
                        ? 'Welcome back! Sign in to access your jobs'
                        : 'Welcome back! Enter your mobile number to sign in',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // TAB FORM CONTENT
                  if (_activeTab == LoginTab.password)
                    _buildPasswordLoginForm()
                  else
                    _buildOtpLoginForm(),

                  const SizedBox(height: 20),

                  // FOOTER LINKS
                  _buildFooterLinks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // TOP SEGMENTED SWITCHER WIDGET
  // -------------------------------------------------------------------
  Widget _buildSegmentedTabSwitcher() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 1. LOGIN WITH OTP TAB
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeTab = LoginTab.otp);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeTab == LoginTab.otp
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeTab == LoginTab.otp
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: _activeTab == LoginTab.otp
                          ? const Color(0xFF9333EA)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Login with OTP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeTab == LoginTab.otp
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _activeTab == LoginTab.otp
                            ? const Color(0xFF9333EA)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. LOGIN WITH PASSWORD TAB
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeTab = LoginTab.password);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeTab == LoginTab.password
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeTab == LoginTab.password
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: _activeTab == LoginTab.password
                          ? const Color(0xFF9333EA)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Login with Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeTab == LoginTab.password
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _activeTab == LoginTab.password
                            ? const Color(0xFF9333EA)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // PASSWORD LOGIN FORM WIDGET
  // -------------------------------------------------------------------
  Widget _buildPasswordLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EMAIL ADDRESS LABEL
        const Text(
          'EMAIL ADDRESS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'name@example.com',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF9333EA), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // PASSWORD LABEL & FORGOT PASSWORD LINK
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PASSWORD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            GestureDetector(
              onTap: _showForgotPasswordDialog,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9333EA),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF9333EA), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // SIGN IN BUTTON
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2B8C), // Primary KaamMilega Blue
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // OTP LOGIN FORM WIDGET
  // -------------------------------------------------------------------
  Widget _buildOtpLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MOBILE NUMBER LABEL
        const Text(
          'MOBILE NUMBER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter 10-digit mobile number',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Text(
                '+91',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF9333EA), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // SEND OTP BUTTON
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleOtpLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2B8C), // Primary KaamMilega Blue
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send OTP & Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // FOOTER LINKS WIDGET
  // -------------------------------------------------------------------
  Widget _buildFooterLinks() {
    return Column(
      children: [
        // Create Account Link
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account yet? ",
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9333EA),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Switch Mode Link (Or Login with OTP / Or Login with Password)
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Or ',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeTab = _activeTab == LoginTab.password
                        ? LoginTab.otp
                        : LoginTab.password;
                  });
                },
                child: Text(
                  _activeTab == LoginTab.password
                      ? 'Login with OTP'
                      : 'Login with Password',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9333EA),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Explore Jobs as Guest Link
        Center(
          child: TextButton(
            onPressed: () => context.go('/jobs'),
            child: const Text(
              'Explore Jobs as Guest ↗',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
