import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/post.dart';
import '../repositories/posts_repository.dart';

/// True when signed in; otherwise shows the standard Login Required popup.
bool requirePostsSignIn(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) {
  if (AuthGuard.isSignedIn(ref.read(authProvider))) return true;
  showAuthPromptDialog(context, title: 'Login Required', message: message);
  return false;
}

/// Shown when Posts are not available (no backend API, DEMO preview off).
void showPostsComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Posts are coming soon. Nothing has been posted.'),
      ),
    );
}

/// Opens the composer ("Create a Post").
///
/// Guests get the Login Required popup. When [openFeedAfter] is true (for
/// example from the + button), the Posts feed opens after a successful post
/// so the new post is visible.
Future<void> openPostComposer(
  BuildContext context,
  WidgetRef ref, {
  bool openFeedAfter = true,
}) async {
  if (!requirePostsSignIn(
    context,
    ref,
    message: 'Please log in to create a post.',
  )) {
    return;
  }
  if (ref.read(postsRepositoryProvider) == null) {
    showPostsComingSoon(context);
    return;
  }
  final created = await context.push<Post>('/posts/new');
  if (created != null && openFeedAfter && context.mounted) {
    context.push('/posts');
  }
}
