import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../home/presentation/widgets/home_section_header.dart';
import '../../../notifications/presentation/notifications_screen.dart'
    show timeAgo;
import '../../../auth/providers/auth_provider.dart';
import '../../models/post.dart';
import '../../providers/posts_provider.dart';
import '../posts_access.dart';
import 'post_basics.dart';
import 'post_attachment.dart';
import 'post_images.dart';

/// One post in the feed / detail: author, text, photos, counts and the
/// React / Comment actions. (No Share: there is no share link for posts.)
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onComment,
    this.expandText = false,
    this.onDeleted,
  });

  final Post post;

  /// Opens the post (null on the detail screen itself).
  final VoidCallback? onOpen;

  /// Comment action; defaults to [onOpen].
  final VoidCallback? onComment;

  /// Show the whole text without "see more".
  final bool expandText;

  /// Called after the member deleted this post (e.g. close the detail).
  final VoidCallback? onDeleted;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDeletePostDialog(context);
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await ref.read(postActionsProvider).delete(post);
      if (!done) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Post deleted.')));
      onDeleted?.call();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Post not deleted. ${postsErrorMessage(e)}')),
        );
    }
  }

  Future<void> _react(
    BuildContext context,
    WidgetRef ref,
    PostReaction? reaction,
  ) async {
    if (!requirePostsSignIn(
      context,
      ref,
      message: 'Please log in to react to posts.',
    )) {
      return;
    }
    final actions = ref.read(postActionsProvider);
    if (actions.isReacting(post.id)) return;
    final ok = await actions.react(post, reaction);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not update your reaction. Please try again.'),
          ),
        );
    }
  }

  Future<void> _pickReaction(BuildContext context, WidgetRef ref) async {
    if (!requirePostsSignIn(
      context,
      ref,
      message: 'Please log in to react to posts.',
    )) {
      return;
    }
    final chosen = await showReactionPicker(context, current: post.myReaction);
    if (chosen == null || !context.mounted) return;
    // Choosing the current reaction again removes it.
    await _react(context, ref, chosen == post.myReaction ? null : chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comment = onComment ?? onOpen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: HomeCardShadow(
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(HomeCard.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  post: post,
                  onDelete: ref.watch(sessionUserIdProvider) == post.author.id
                      ? () => _delete(context, ref)
                      : null,
                ),
                if (post.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _ExpandableText(
                      text: post.text.trim(),
                      expanded: expandText,
                    ),
                  ),
                if (post.images.isNotEmpty) PostImageGrid(images: post.images),
                for (final a in post.attachments)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: PostPdfTile(
                      attachment: a,
                      onTap: () => openPostAttachment(context, a),
                    ),
                  ),
                _Counts(post: post, onComments: comment),
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.borderLight,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ReactButton(
                          reaction: post.myReaction,
                          onTap: () => _react(
                            context,
                            ref,
                            post.myReaction == null ? PostReaction.like : null,
                          ),
                          onLongPress: () => _pickReaction(context, ref),
                        ),
                      ),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.mode_comment_outlined,
                          label: 'Comment',
                          color: AppColors.textSecondary,
                          onTap: comment,
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

class _Header extends StatelessWidget {
  const _Header({required this.post, this.onDelete});

  final Post post;

  /// Shown (as "Delete post" in the menu) only on the member's own posts.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostAuthorAvatar(author: author, size: 46),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (author.headline.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    author.headline.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        timeAgo(post.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.public_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Post options',
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              position: PopupMenuPosition.under,
              onSelected: (_) => onDelete!(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Delete post',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Post text with "see more" / "show less" when longer than [trimLines].
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text, this.expanded = false});

  final String text;
  final bool expanded;

  static const int trimLines = 5;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  late bool _expanded = widget.expanded;

  static const _style = TextStyle(
    fontSize: 14.5,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.expanded) return Text(widget.text, style: _style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: _ExpandableText.trimLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: _style,
                maxLines: _expanded ? null : _ExpandableText.trimLines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _expanded ? 'Show less' : 'See more',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.post, this.onComments});

  final Post post;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) {
    final total = post.reactionTotal;
    final comments = post.commentCount;
    if (total == 0 && comments == 0) return const SizedBox(height: 6);
    final top = post.topReactions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          if (total > 0) ...[
            SizedBox(
              width: 18.0 + (top.length - 1) * 12,
              height: 18,
              child: Stack(
                children: [
                  for (var i = 0; i < top.length; i++)
                    Positioned(
                      left: i * 12.0,
                      child: ReactionDot(reaction: top[i]),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: total == 1 ? '1 reaction' : '$total reactions',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (comments > 0)
            Flexible(
              child: InkWell(
                onTap: onComments,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    comments == 1 ? '1 comment' : '$comments comments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactButton extends StatelessWidget {
  const _ReactButton({
    required this.reaction,
    required this.onTap,
    required this.onLongPress,
  });

  final PostReaction? reaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final r = reaction;
    return Semantics(
      onLongPressHint: 'Choose a reaction',
      child: _ActionButton(
        icon: r == null ? Icons.thumb_up_alt_outlined : ReactionStyle.icon(r),
        label: r == null ? 'Like' : r.label,
        color: r == null ? AppColors.textSecondary : ReactionStyle.color(r),
        selected: r != null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(icon, key: ValueKey(icon), size: 20, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: color,
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
