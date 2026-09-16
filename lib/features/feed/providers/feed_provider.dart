import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/feed_post.dart';
import '../repositories/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(apiClientProvider));
});

class FeedNotifier extends AsyncNotifier<List<FeedPost>> {
  @override
  Future<List<FeedPost>> build() async {
    return ref.read(feedRepositoryProvider).getFeedPosts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(feedRepositoryProvider).getFeedPosts(),
    );
  }

  Future<void> createPost({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String authorHeadline,
    required String content,
    String mediaUrl = '',
    String mediaType = 'none',
    String documentName = '',
  }) async {
    final repository = ref.read(feedRepositoryProvider);
    final newPost = await repository.createPost(
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorHeadline: authorHeadline,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      documentName: documentName,
    );

    state = AsyncValue.data([newPost, ...?state.value]);
  }

  void toggleReaction(String postId, String reaction) {
    final currentList = state.value ?? [];
    state = AsyncValue.data(
      currentList.map((post) {
        if (post.id == postId) {
          final isSame = post.userReaction == reaction;
          final newReaction = isSame ? '' : reaction;
          final newLikesCount = isSame
              ? (post.likesCount > 0 ? post.likesCount - 1 : 0)
              : (post.userReaction.isEmpty
                    ? post.likesCount + 1
                    : post.likesCount);

          return post.copyWith(
            userReaction: newReaction,
            likesCount: newLikesCount,
          );
        }
        return post;
      }).toList(),
    );
  }

  void addComment(
    String postId,
    String commentText,
    String authorName,
    String authorAvatar,
  ) {
    if (commentText.trim().isEmpty) return;
    final newComment = PostComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName.isNotEmpty ? authorName : 'User',
      authorAvatar: authorAvatar,
      content: commentText.trim(),
      createdAt: DateTime.now(),
    );

    final currentList = state.value ?? [];
    state = AsyncValue.data(
      currentList.map((post) {
        if (post.id == postId) {
          final updatedComments = [...post.comments, newComment];
          return post.copyWith(
            comments: updatedComments,
            commentsCount: updatedComments.length,
          );
        }
        return post;
      }).toList(),
    );
  }
}

final feedPostsProvider = AsyncNotifierProvider<FeedNotifier, List<FeedPost>>(
  FeedNotifier.new,
);
