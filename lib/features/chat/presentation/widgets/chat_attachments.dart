import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../repositories/chat_repository.dart';

/// Where the user picks a file from.
enum ChatPickSource { gallery, camera, document }

/// A file picked on the device, not uploaded yet.
class PickedChatFile {
  const PickedChatFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  int get size => bytes.length;

  bool get isImage => ChatRepository.mimeTypeFor(name).startsWith('image/');
}

/// Opens the gallery, camera or document picker. Null when cancelled.
typedef ChatFilePicker = Future<PickedChatFile?> Function(
  ChatPickSource source,
);

Future<PickedChatFile?> _pickFromDevice(ChatPickSource source) async {
  if (source == ChatPickSource.document) {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'txt'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return PickedChatFile(name: file.name, bytes: bytes);
  }
  final image = await ImagePicker().pickImage(
    source: source == ChatPickSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1920,
  );
  if (image == null) return null;
  return PickedChatFile(name: image.name, bytes: await image.readAsBytes());
}

/// The device pickers; replaced in tests.
final chatFilePickerProvider = Provider<ChatFilePicker>(
  (ref) => _pickFromDevice,
);

/// "Photo / Camera / Document" sheet. Null when dismissed.
Future<ChatPickSource?> showAttachmentOptions(BuildContext context) {
  Widget option(ChatPickSource source, IconData icon, String label) => ListTile(
    leading: CircleAvatar(
      backgroundColor: AppColors.blue.withValues(alpha: 0.1),
      child: Icon(icon, color: AppColors.blue),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    onTap: () => Navigator.pop(context, source),
  );
  return showModalBottomSheet<ChatPickSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Share',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          option(ChatPickSource.gallery, Icons.photo_library_rounded, 'Photo'),
          // No camera in the browser build.
          if (!kIsWeb)
            option(ChatPickSource.camera, Icons.photo_camera_rounded, 'Camera'),
          option(
            ChatPickSource.document,
            Icons.description_rounded,
            'Document (PDF, DOC, DOCX, TXT)',
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The picked file shown above the message box before sending.
class PendingAttachmentPreview extends StatelessWidget {
  const PendingAttachmentPreview({
    super.key,
    required this.file,
    required this.onRemove,
  });

  final PickedChatFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: file.isImage
                  ? Image.memory(
                      Uint8List.fromList(file.bytes),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _FileIcon(),
                    )
                  : const _FileIcon(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  formatFileSize(file.size),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blue.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: const Icon(Icons.description_rounded, color: AppColors.blue),
    );
  }
}

/// An image or file inside a message bubble. Images open full screen;
/// files open in the phone's viewer or browser.
class MessageAttachmentView extends StatelessWidget {
  const MessageAttachmentView({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  final ChatAttachment attachment;
  final bool isMe;

  Future<void> _openFile(BuildContext context) async {
    final uri = Uri.tryParse(attachment.resolvedUrl);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the file.')));
    }
  }

  void _openImage(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: 0.9),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image.network(
                  attachment.resolvedUrl,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return Semantics(
        button: true,
        label: attachment.name.isNotEmpty ? attachment.name : 'Photo',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _openImage(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 120),
              child: Image.network(
                attachment.resolvedUrl,
                fit: BoxFit.cover,
                // Keep the bubble its size until the photo arrives.
                frameBuilder: (context, child, frame, wasSync) =>
                    frame != null || wasSync
                    ? child
                    : Container(
                        width: 180,
                        height: 140,
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                errorBuilder: (_, _, _) => Container(
                  width: 180,
                  height: 120,
                  color: AppColors.background,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final fg = isMe ? AppColors.white : AppColors.brandNavy;
    final name = attachment.name.isNotEmpty ? attachment.name : 'Document';
    final size = attachment.sizeLabel;
    return Semantics(
      button: true,
      label: 'Open $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openFile(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.white.withValues(alpha: 0.15)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                  ? AppColors.white.withValues(alpha: 0.25)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_rounded, color: fg, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if (size.isNotEmpty)
                      Text(
                        size,
                        style: TextStyle(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
