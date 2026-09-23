import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../jobs/models/job.dart';
import '../repositories/application_repository.dart';

/// Modal bottom sheet to apply for a job with optional cover letter
class ApplyModalSheet extends ConsumerStatefulWidget {
  final Job job;
  final VoidCallback onSuccess;

  const ApplyModalSheet({
    super.key,
    required this.job,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required Job job,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApplyModalSheet(job: job, onSuccess: onSuccess),
    );
  }

  @override
  ConsumerState<ApplyModalSheet> createState() => _ApplyModalSheetState();
}

class _ApplyModalSheetState extends ConsumerState<ApplyModalSheet> {
  final TextEditingController _coverLetterController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Apply',
        message: 'Please sign in or register to apply for ${widget.job.title}.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(applicationRepositoryProvider)
          .applyToJob(
            widget.job.id,
            coverLetter: _coverLetterController.text.trim(),
            resumeUrl: ref.read(authProvider).user?.resumeUrl ?? '',
          );

      ref.invalidate(myApplicationsProvider);

      if (mounted) {
        final jobId = widget.job.id;
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Application submitted successfully!'),
              ],
            ),
          ),
        );
        context.push('/applications/$jobId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errStr = e.toString();
        final displayMsg = errStr.contains('already applied')
            ? 'You have already applied for this job.'
            : errStr;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(displayMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Company
            Text(
              widget.job.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Applying to ${widget.job.company}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 20),

            // Note / Cover letter field
            const Text(
              'Cover Note / Introduction (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _coverLetterController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Briefly tell the recruiter why you are a great match for this role...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryGradientStart,
                    AppColors.primaryGradientEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Application',
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
  }
}
