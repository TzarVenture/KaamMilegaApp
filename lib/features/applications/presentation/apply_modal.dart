import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../jobs/models/job.dart';
import '../repositories/application_repository.dart';

/// A resume file the user picked for one application.
class PickedResume {
  const PickedResume({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  int get size => bytes.length;
}

/// Opens the system file picker for a PDF, DOC or DOCX. Null when the user
/// cancels or the file could not be read.
typedef ResumePicker = Future<PickedResume?> Function();

Future<PickedResume?> _pickResumeFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'doc', 'docx'],
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return PickedResume(name: file.name, bytes: bytes);
}

/// "Apply for Position" sheet, as on the website: the applicant's profile,
/// an optional resume for this application and an optional note.
///
/// The resume is uploaded (POST /files/upload) only when the user submits,
/// and its link goes with POST /applications as `resume_url`. Without one,
/// the resume saved on the profile (if any) is sent instead.
class ApplyModalSheet extends ConsumerStatefulWidget {
  final Job job;
  final VoidCallback onSuccess;
  final ResumePicker pickResume;

  const ApplyModalSheet({
    super.key,
    required this.job,
    required this.onSuccess,
    this.pickResume = _pickResumeFile,
  });

  /// Largest resume accepted (same as the website).
  static const int maxResumeBytes = 5 * 1024 * 1024;

  /// Longest note to the recruiter (same as the website).
  static const int maxNoteLength = 500;

  static Future<void> show(
    BuildContext context, {
    required Job job,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApplyModalSheet(job: job, onSuccess: onSuccess),
    );
  }

  @override
  ConsumerState<ApplyModalSheet> createState() => _ApplyModalSheetState();
}

class _ApplyModalSheetState extends ConsumerState<ApplyModalSheet> {
  final TextEditingController _noteController = TextEditingController();
  PickedResume? _resume;
  String? _resumeError;
  bool _isLoading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _attachResume() async {
    if (_isLoading) return;
    try {
      final picked = await widget.pickResume();
      if (!mounted || picked == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      if (!const ['pdf', 'doc', 'docx'].contains(ext)) {
        setState(() => _resumeError = 'Please choose a PDF, DOC or DOCX file.');
        return;
      }
      if (picked.size > ApplyModalSheet.maxResumeBytes) {
        setState(() => _resumeError = 'Resume file must be under 5MB.');
        return;
      }
      setState(() {
        _resume = picked;
        _resumeError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _resumeError = 'Could not open the file. Please try again.',
        );
      }
    }
  }

  void _removeResume() => setState(() {
    _resume = null;
    _resumeError = null;
  });

  void _editProfile() {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/profile');
  }

  static bool _isConflict(Object e) {
    final original = e is AppException ? e.originalError : e;
    return original is DioException && original.response?.statusCode == 409;
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: color, content: Text(message)));
  }

  Future<void> _submitApplication() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Apply',
        message: 'Please sign in or register to apply for ${widget.job.title}.',
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Upload the attached resume (if any) to get its link.
    var resumeUrl = auth.user?.resumeUrl ?? '';
    final resume = _resume;
    if (resume != null) {
      try {
        final url = await ref
            .read(authRepositoryProvider)
            .uploadFile(resume.bytes, resume.name);
        if (url == null || url.isEmpty) {
          throw const AppValidationException('No file link was returned.');
        }
        resumeUrl = url;
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnack(
          'Could not upload your resume: $e. Remove it or try again.',
          AppColors.error,
        );
        return;
      }
    }

    // 2. Send the application.
    try {
      await ref
          .read(applicationRepositoryProvider)
          .applyToJob(
            widget.job.id,
            coverLetter: _noteController.text.trim(),
            resumeUrl: resumeUrl,
          );

      ref.invalidate(myApplicationsProvider);

      if (!mounted) return;
      final jobId = widget.job.id;
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onSuccess();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'Application submitted. Track its status in My Applications.',
          ),
        ),
      );
      router.push('/applications/$jobId');
    } catch (e) {
      if (!mounted) return;
      if (_isConflict(e)) {
        // 409: the server already has an application from this user.
        ref.invalidate(myApplicationsProvider);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        widget.onSuccess();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You have already applied for this job.'),
          ),
        );
        return;
      }
      setState(() => _isLoading = false);
      _showSnack(e.toString(), AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                20 + media.padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Header(
                    job: widget.job,
                    onClose: _isLoading ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 18),
                  _ProfileStrip(
                    user: user,
                    onEdit: _isLoading ? null : _editProfile,
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(
                    title: 'Attach Resume',
                    trailing: 'PDF, DOC, DOCX up to 5MB',
                  ),
                  const SizedBox(height: 8),
                  if (_resume == null)
                    _ResumeDropzone(
                      onTap: _isLoading ? null : _attachResume,
                      hasProfileResume: (user?.resumeUrl ?? '').isNotEmpty,
                    )
                  else
                    _AttachedResume(
                      resume: _resume!,
                      onRemove: _isLoading ? null : _removeResume,
                    ),
                  if (_resumeError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _resumeError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _noteController,
                    builder: (context, value, _) => _FieldLabel(
                      title: 'Pitch or Note to Recruiter',
                      trailing:
                          '${value.text.characters.length}/${ApplyModalSheet.maxNoteLength}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    enabled: !_isLoading,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: ApplyModalSheet.maxNoteLength,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Add relevant experience, key certifications, or immediate availability...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.blue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Actions(
                    isLoading: _isLoading,
                    onCancel: () => Navigator.pop(context),
                    onSubmit: _submitApplication,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.job, required this.onClose});

  final Job job;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      job.title,
      job.company,
    ].where((s) => s.trim().isNotEmpty).join(' • ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apply for Position',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({required this.user, required this.onEdit});

  final UserProfile? user;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final name = (user?.name ?? '').trim();
    final initial = name.isEmpty ? 'C' : name.characters.first.toUpperCase();
    final contact = [user?.mobile, user?.email, user?.city]
        .map((s) => (s ?? '').trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final verified = user?.isEmailVerified ?? false;

    final editButton = TextButton(
      onPressed: onEdit,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Edit Profile',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow phones or with large text, "Edit Profile" moves under
          // the details so the name keeps its room.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final narrow = constraints.maxWidth < 290 * scale;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name.isEmpty ? 'Candidate' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Shown only when the server says the email is verified.
                  if (verified) const _VerifiedChip(),
                ],
              ),
              if (contact.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (narrow)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: editButton,
                ),
            ],
          );
          return Row(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: details),
              if (!narrow) ...[const SizedBox(width: 8), editButton],
            ],
          );
        },
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.verifiedBlueBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
          SizedBox(width: 3),
          Flexible(
            child: Text(
              'Verified',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: title,
              children: const [
                TextSpan(
                  text: ' (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumeDropzone extends StatelessWidget {
  const _ResumeDropzone({required this.onTap, required this.hasProfileResume});

  final VoidCallback? onTap;
  final bool hasProfileResume;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Attach resume',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: const _DashedBorderPainter(
            color: AppColors.border,
            radius: 14,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 22,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tap to upload your resume',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasProfileResume
                      ? 'If you skip this, the resume on your profile is sent.'
                      : 'Your profile details are sent with your application.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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

class _AttachedResume extends StatelessWidget {
  const _AttachedResume({required this.resume, required this.onRemove});

  final PickedResume resume;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final kb = (resume.size / 1024).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 20,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$kb KB • Attached',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove resume',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.isLoading,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: isLoading ? null : onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: shape,
            ),
            child: const Text(
              'Cancel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.brandNavy,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.brandNavy.withValues(
                alpha: 0.6,
              ),
              disabledForegroundColor: AppColors.white,
              elevation: 0,
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.white,
                    ),
                  ),
                if (isLoading) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isLoading ? 'Submitting...' : 'Submit Application',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isLoading) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.north_east_rounded, size: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashed rounded border for the resume drop area.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dash = 6.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
