import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/feed_provider.dart';

class CreatePostModal extends ConsumerStatefulWidget {
  const CreatePostModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreatePostModal(),
    );
  }

  @override
  ConsumerState<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends ConsumerState<CreatePostModal> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _mediaUrl = '';
  String _mediaType = 'none'; // 'image', 'pdf', 'none'
  String _documentName = '';
  String _visibility = 'Anyone';
  bool _isPosting = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _mediaUrl = image.path;
          _mediaType = 'image';
          _documentName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _mediaUrl = file.path ?? file.name;
          _mediaType = 'pdf';
          _documentName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearAttachment() {
    setState(() {
      _mediaUrl = '';
      _mediaType = 'none';
      _documentName = '';
    });
  }

  Future<void> _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _mediaType == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter post text or attach media/document.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    final user = ref.read(authProvider).user;
    await ref
        .read(feedPostsProvider.notifier)
        .createPost(
          authorId: user?.id ?? '',
          authorName: user?.name ?? 'Candidate User',
          authorAvatar: user?.profileImage ?? '',
          authorHeadline: user?.headline ?? 'Candidate on KaamMilega',
          content: text,
          mediaUrl: _mediaUrl,
          mediaType: _mediaType,
          documentName: _documentName,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your post was published successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?.name.isNotEmpty == true
        ? user!.name
        : 'Candidate User';
    final userAvatar = user?.profileImage ?? '';
    final userHeadline = user?.headline.isNotEmpty == true
        ? user!.headline
        : 'Candidate on KaamMilega';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
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
            // Header bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Start a Post',
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Author Profile Row with Visibility Selector
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.heroBg,
                  backgroundImage: userAvatar.isNotEmpty
                      ? NetworkImage(userAvatar)
                      : null,
                  child: userAvatar.isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userHeadline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _visibility,
                      isDense: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.primary,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      onChanged: (val) {
                        if (val != null) setState(() => _visibility = val);
                      },
                      items: ['Anyone', 'Connections Only']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Textfield for post content
            TextField(
              controller: _contentController,
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(fontSize: 15, height: 1.4),
              decoration: const InputDecoration(
                hintText: 'What do you want to talk about? Share an update, opportunity, or milestone...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),

            // Media attachment preview if selected
            if (_mediaType != 'none') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mediaType == 'image'
                          ? Icons.image_rounded
                          : Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mediaType == 'image'
                                ? 'Image Attached'
                                : 'Document Attached',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _documentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: AppColors.error,
                      ),
                      onPressed: _clearAttachment,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Divider(height: 1),
            const SizedBox(height: 12),

            // Bottom Attachment Toolbar & Post Button
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Add Photo',
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Add Document / PDF',
                  onPressed: _pickDocument,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isPosting ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
}
