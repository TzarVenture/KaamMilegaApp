import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../models/post.dart';

/// A PDF attached to a post: icon, file name and size. Shows a remove
/// button in the composer ([onRemove]) and opens on tap in the feed.
class PostPdfTile extends StatelessWidget {
  const PostPdfTile({
    super.key,
    required this.attachment,
    this.onTap,
    this.onRemove,
  });

  final PostAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'PDF ${attachment.name}, ${attachment.sizeLabel}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.hotRoseBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.hotRose,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PDF  |  ${attachment.sizeLabel}',
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
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove PDF',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  )
                else if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
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

/// Opens a post's PDF. A server file opens in the device viewer; a DEMO
/// file only exists on this device, so the user is told it cannot open yet.
Future<void> openPostAttachment(
  BuildContext context,
  PostAttachment attachment,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final url = attachment.url;
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('This PDF can be opened once posts go live.'),
        ),
      );
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Could not open the PDF.')));
  }
}

/// "Delete this post?" confirmation. True when the user confirms.
Future<bool?> showDeletePostDialog(BuildContext context) {
  return showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this post?'),
      content: const Text(
        'The post, its reactions and comments will be removed. This cannot '
        'be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
