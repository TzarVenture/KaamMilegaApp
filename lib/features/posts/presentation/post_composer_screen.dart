import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/post.dart';
import '../providers/post_image_picker.dart';
import '../providers/posts_provider.dart';
import '../repositories/posts_repository.dart';
import 'posts_screen.dart' show PostsUnavailableView;
import 'widgets/post_attachment.dart';
import 'widgets/post_basics.dart';

/// "Create a post": text and up to [maxImages] photos. Pops with the
/// created [Post] on success; the draft is kept when posting fails.
class PostComposerScreen extends ConsumerStatefulWidget {
  const PostComposerScreen({super.key});

  static const int maxChars = 3000;
  static const int maxImages = 4;
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxPdfBytes = 10 * 1024 * 1024;

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  final _controller = TextEditingController();
  final List<NewPostImage> _images = [];
  PostAttachment? _pdf;
  bool _submitting = false;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _length => _controller.text.trim().length;

  bool get _hasDraft => _length > 0 || _images.isNotEmpty || _pdf != null;

  bool get _tooLong => _length > PostComposerScreen.maxChars;

  bool get _canSubmit => !_submitting && _hasDraft && !_tooLong;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addImages() async {
    if (_picking || _submitting) return;
    final remaining = PostComposerScreen.maxImages - _images.length;
    if (remaining <= 0) {
      _snack('You can add up to ${PostComposerScreen.maxImages} photos.');
      return;
    }
    setState(() => _picking = true);
    try {
      final picked = await ref.read(postImagePickerProvider)(limit: remaining);
      if (!mounted || picked.isEmpty) return;
      final fitting = picked
          .where(
            (i) => i.bytes.lengthInBytes <= PostComposerScreen.maxImageBytes,
          )
          .toList();
      final accepted = fitting.take(remaining).toList();
      setState(() => _images.addAll(accepted));
      if (fitting.length < picked.length) {
        _snack('Photos larger than 10 MB were not added.');
      } else if (accepted.length < fitting.length) {
        _snack('Only ${PostComposerScreen.maxImages} photos can be added.');
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'Could not open your photos. Please allow photo access and try '
          'again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addPdf() async {
    if (_picking || _submitting) return;
    setState(() => _picking = true);
    try {
      final picked = await ref.read(postPdfPickerProvider)();
      if (!mounted || picked == null) return;
      if (!picked.name.toLowerCase().endsWith('.pdf')) {
        _snack('Only PDF files can be attached.');
      } else if (picked.sizeBytes > PostComposerScreen.maxPdfBytes) {
        _snack('PDFs larger than 10 MB cannot be attached.');
      } else {
        setState(() => _pdf = picked);
      }
    } catch (_) {
      if (mounted) _snack('Could not open your files. Please try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeImage(int index) {
    if (_submitting) return;
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final post = await ref
          .read(postActionsProvider)
          .create(
            text: _controller.text.trim(),
            images: List.of(_images),
            attachments: [?_pdf],
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Post published.')));
      // Navigator.pop is not blocked by the draft guard below.
      navigator.pop(post);
    } on PostsSignInRequired {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAuthPromptDialog(
        context,
        title: 'Login Required',
        message: 'Please log in to create a post.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Your post was not published. ${postsErrorMessage(e)}';
      });
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this post?'),
        content: const Text('Your text and photos will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postsRepositoryProvider);
    final author = postAuthorFrom(ref.watch(authProvider).user);

    return PopScope(
      canPop: !_submitting && !_hasDraft,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting) return;
        _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Create a post',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (repo != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    minimumSize: const Size(72, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const StadiumBorder(),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Post'),
                ),
              ),
          ],
        ),
        body: repo == null
            ? const PostsUnavailableView()
            : Column(
                children: [
                  if (_submitting) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        if (author != null) _AuthorRow(author: author),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          enabled: !_submitting,
                          autofocus: true,
                          minLines: 6,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'What do you want to talk about?',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                        if (_length > PostComposerScreen.maxChars - 300)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$_length / ${PostComposerScreen.maxChars}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _tooLong
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ImagePreviews(
                            images: _images,
                            onRemove: _submitting ? null : _removeImage,
                          ),
                        ],
                        if (_pdf != null) ...[
                          const SizedBox(height: 12),
                          PostPdfTile(
                            attachment: _pdf!,
                            onRemove: _submitting
                                ? null
                                : () => setState(() => _pdf = null),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _error!),
                        ],
                      ],
                    ),
                  ),
                  _Toolbar(
                    imageCount: _images.length,
                    busy: _submitting || _picking,
                    onAddImages: _addImages,
                    hasPdf: _pdf != null,
                    onAddPdf: _addPdf,
                  ),
                ],
              ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.author});

  final PostAuthor author;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PostAuthorAvatar(author: author, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Anyone on KaamMilega',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImagePreviews extends StatelessWidget {
  const _ImagePreviews({required this.images, required this.onRemove});

  final List<NewPostImage> images;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - 8) / 2;
        final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 1024);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < images.length; i++)
              SizedBox(
                width: size,
                height: size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        images[i].bytes,
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        semanticLabel: 'Selected photo ${i + 1}',
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.skeleton,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: AppColors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Remove photo ${i + 1}',
                            visualDensity: VisualDensity.compact,
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(i),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.hotRoseBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hotRoseBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.imageCount,
    required this.busy,
    required this.onAddImages,
    required this.hasPdf,
    required this.onAddPdf,
  });

  final int imageCount;
  final bool busy;
  final VoidCallback onAddImages;
  final bool hasPdf;
  final VoidCallback onAddPdf;

  @override
  Widget build(BuildContext context) {
    final full = imageCount >= PostComposerScreen.maxImages;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: busy || full ? null : onAddImages,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    'Add photos ($imageCount/${PostComposerScreen.maxImages})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.moduleSkills,
                  ),
                ),
              ),
              Flexible(
                child: TextButton.icon(
                  onPressed: busy || hasPdf ? null : onAddPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    hasPdf ? 'PDF added' : 'Add PDF',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.hotRose,
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
