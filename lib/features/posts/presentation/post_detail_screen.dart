import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show timeAgo;
import '../models/post.dart';
import '../providers/posts_provider.dart';
import '../repositories/posts_repository.dart';
import 'posts_screen.dart' show PostsUnavailableView;
import 'widgets/post_basics.dart';
import 'widgets/post_card.dart';

/// One post with its comments and a comment box.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.focusComment = false,
  });

  final String postId;

  /// Open with the keyboard on the comment box (from "Comment").
  final bool focusComment;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canComment) _commentFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canComment => AuthGuard.isSignedIn(ref.read(authProvider));

  void _focusCommentBox() {
    if (!_canComment) {
      _askToLogin();
      return;
    }
    _commentFocus.requestFocus();
  }

  void _askToLogin() => showAuthPromptDialog(
    context,
    title: 'Login Required',
    message: 'Please log in to comment on posts.',
  );

  Future<void> _send() async {
    final text = _commentController.text.trim();
    final notifier = ref.read(postCommentsProvider(widget.postId).notifier);
    if (text.isEmpty) return;
    if (!_canComment) {
      _askToLogin();
      return;
    }
    final error = await notifier.add(text);
    if (!mounted) return;
    if (error == null) {
      _commentController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      return;
    }
    if (error is PostsSignInRequired) {
      _askToLogin();
      return;
    }
    // Keep the typed comment so it can be sent again.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Comment not posted. ${postsErrorMessage(error)}'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postsRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        // The app theme colours app bar icons navy; white on this navy bar.
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
        surfaceTintColor: AppColors.brandNavy,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: 4,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/posts'),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: repo == null ? const PostsUnavailableView() : _buildBody(),
    );
  }

  Widget _buildBody() {
    final detail = ref.watch(postDetailProvider(widget.postId));
    final notifier = ref.read(postDetailProvider(widget.postId).notifier);
    return switch (detail) {
      AsyncData(:final value) => _buildPost(value),
      AsyncError(:final error) => NetworkStateView(
        isOffline: error is AppNetworkException,
        errorMessage: postsErrorMessage(error),
        onRetry: notifier.reload,
        child: const SizedBox.shrink(),
      ),
      _ => const PostsSkeletonList(),
    };
  }

  Widget _buildPost(Post post) {
    final comments = ref.watch(postCommentsProvider(widget.postId));
    final commentsNotifier = ref.read(
      postCommentsProvider(widget.postId).notifier,
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            children: [
              PostCard(
                post: post,
                expandText: true,
                onComment: _focusCommentBox,
                onDeleted: () =>
                    context.canPop() ? context.pop() : context.go('/posts'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  post.commentCount > 0
                      ? 'Comments (${post.commentCount})'
                      : 'Comments',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ..._buildComments(comments, commentsNotifier.load),
            ],
          ),
        ),
        _CommentBar(
          controller: _commentController,
          focusNode: _commentFocus,
          isSending: comments.isSending,
          signedIn: AuthGuard.isSignedIn(ref.watch(authProvider)),
          author: postAuthorFrom(ref.watch(authProvider).user),
          onSend: _send,
          onLogin: _askToLogin,
        ),
      ],
    );
  }

  List<Widget> _buildComments(
    PostCommentsState state,
    Future<void> Function() retry,
  ) {
    if (state.isLoading && state.comments.isEmpty) {
      return const [_CommentSkeleton(), _CommentSkeleton()];
    }
    if (state.error != null && state.comments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                'Could not load comments. ${postsErrorMessage(state.error!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ];
    }
    if (state.comments.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            'No comments yet. Start the conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ];
    }
    return [for (final c in state.comments) _CommentTile(comment: c)];
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostAuthorAvatar(author: author, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  topLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (author.headline.trim().isNotEmpty)
                    Text(
                      author.headline.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    comment.text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentSkeleton extends StatelessWidget {
  const _CommentSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerCircle(size: 36),
          SizedBox(width: 10),
          Expanded(
            child: ShimmerBox(
              width: double.infinity,
              height: 64,
              borderRadius: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBar extends StatelessWidget {
  const _CommentBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.signedIn,
    required this.author,
    required this.onSend,
    required this.onLogin,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool signedIn;
  final PostAuthor? author;
  final VoidCallback onSend;
  final VoidCallback onLogin;

  static const int maxLength = 1000;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: AppColors.brandNavy.withValues(alpha: 0.2),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: !signedIn
              ? SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Log in to comment'),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (author != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: PostAuthorAvatar(author: author!, size: 32),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !isSending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.blue),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          // Only the send button rebuilds while typing.
                          : ValueListenableBuilder<TextEditingValue>(
                              valueListenable: controller,
                              builder: (context, value, _) {
                                final canSend = value.text.trim().isNotEmpty;
                                return IconButton(
                                  tooltip: 'Post comment',
                                  onPressed: canSend ? onSend : null,
                                  icon: Icon(
                                    Icons.send_rounded,
                                    color: canSend
                                        ? AppColors.blue
                                        : AppColors.textMuted,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
