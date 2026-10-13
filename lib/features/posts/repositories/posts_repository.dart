import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import 'demo_posts_repository.dart';

/// Posts preview switch (TEMPORARY hardcoded DEMO data).
///
/// The KaamMilega backend has no posts, feed, reaction or comment API yet
/// (verified against km-backend). For now debug/profile builds show local,
/// in-memory DEMO posts (labelled DEMO) so the UI can be checked. Nothing
/// is sent to the server.
///
/// To hide the demo: flutter run --dart-define=KM_POSTS_DEMO=false
/// Release builds never show it. Remove this when the posts API exists.
const bool kPostsDemoMode =
    !kReleaseMode && bool.fromEnvironment('KM_POSTS_DEMO', defaultValue: true);

/// Which posts a list shows.
enum PostsScope { feed, mine }

/// Data source for posts.
///
/// When the backend adds the posts API, add an ApiClient-backed
/// implementation and return it from [postsRepositoryProvider]; the screens
/// do not change.
abstract interface class PostsRepository {
  /// True for the local DEMO preview (labelled DEMO in the UI).
  bool get isDemo;

  /// [page] starts at 1. [viewerId] is the signed-in member (needed for
  /// [PostsScope.mine]).
  Future<PostsPage> fetchPosts({
    required PostsScope scope,
    required String? viewerId,
    required int page,
    required int pageSize,
  });

  Future<Post> fetchPost(String postId);

  Future<Post> createPost({
    required PostAuthor author,
    required String text,
    required List<NewPostImage> images,
    List<PostAttachment> attachments = const [],
  });

  /// Deletes a post. Only its author may do this (checked before calling).
  Future<void> deletePost(String postId);

  /// Sets the signed-in member's reaction; null removes it.
  Future<void> setReaction({
    required String postId,
    required PostReaction? reaction,
  });

  Future<List<PostComment>> fetchComments(String postId);

  Future<PostComment> addComment({
    required String postId,
    required PostAuthor author,
    required String text,
  });
}

/// Null while the backend has no posts API and DEMO preview is off: the
/// screens then show "Posts are coming soon" and never fake data.
final postsRepositoryProvider = Provider<PostsRepository?>((ref) {
  if (kPostsDemoMode) return DemoPostsRepository();
  return null;
});
