import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/post.dart';
import '../repositories/posts_repository.dart';

/// User-facing text for a failed posts request.
String postsErrorMessage(Object error) {
  if (error is AppException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

/// The signed-in member as a post author, or null for guests.
PostAuthor? postAuthorFrom(UserProfile? user) {
  if (user == null || user.id.isEmpty) return null;
  return PostAuthor(
    id: user.id,
    name: user.name.trim().isEmpty ? 'KaamMilega member' : user.name.trim(),
    headline: user.headline,
    avatarUrl: user.profileImage,
  );
}

// ---------------------------------------------------------------------------
// Feed / My posts
// ---------------------------------------------------------------------------

class PostsFeedState {
  const PostsFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.loadMoreError,
    this.page = 0,
  });

  final List<Post> posts;

  /// First page (or a refresh) is loading.
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// First page failed (shown full screen with Retry).
  final Object? error;

  /// A later page failed (shown at the end of the list with Retry).
  final Object? loadMoreError;

  /// Last loaded page (0 = none yet).
  final int page;

  PostsFeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    Object? loadMoreError,
    int? page,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) => PostsFeedState(
    posts: posts ?? this.posts,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
    page: page ?? this.page,
  );
}

class PostsFeedNotifier extends Notifier<PostsFeedState> {
  PostsFeedNotifier(this.scope);

  final PostsScope scope;
  static const int pageSize = 10;

  /// Bumped on every refresh so a slow, older response is ignored.
  int _generation = 0;

  @override
  PostsFeedState build() {
    // Another account must never see this account's list.
    ref.watch(sessionUserIdProvider);
    if (ref.watch(postsRepositoryProvider) == null) {
      return const PostsFeedState();
    }
    Future.microtask(refresh);
    return const PostsFeedState(isLoading: true);
  }

  Future<void> refresh() async {
    final repo = ref.read(postsRepositoryProvider);
    if (repo == null) return;
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final result = await repo.fetchPosts(
        scope: scope,
        viewerId: ref.read(sessionUserIdProvider),
        page: 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      state = PostsFeedState(
        posts: result.posts,
        hasMore: result.hasMore,
        page: 1,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      // Keep any posts already shown; the error is still reported.
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final repo = ref.read(postsRepositoryProvider);
    final current = state;
    if (repo == null ||
        current.isLoading ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    state = current.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final result = await repo.fetchPosts(
        scope: scope,
        viewerId: ref.read(sessionUserIdProvider),
        page: current.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final p in state.posts) p.id};
      state = state.copyWith(
        posts: [
          ...state.posts,
          ...result.posts.where((p) => !known.contains(p.id)),
        ],
        hasMore: result.hasMore,
        page: current.page + 1,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  /// Adds a post the member just created (once) at the top.
  void insertCreated(Post post) {
    if (state.posts.any((p) => p.id == post.id)) return;
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  /// Removes a deleted post from this list.
  void remove(String postId) {
    if (!state.posts.any((p) => p.id == postId)) return;
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id != postId) p,
      ],
    );
  }

  /// Replaces the shown copy of [post], if this list has it.
  void replace(Post post) {
    final index = state.posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;
    final next = [...state.posts]..[index] = post;
    state = state.copyWith(posts: next);
  }
}

final postsFeedProvider = NotifierProvider.autoDispose
    .family<PostsFeedNotifier, PostsFeedState, PostsScope>(
      PostsFeedNotifier.new,
    );

// ---------------------------------------------------------------------------
// Single post (detail screen)
// ---------------------------------------------------------------------------

class PostDetailNotifier extends Notifier<AsyncValue<Post>> {
  PostDetailNotifier(this.postId);

  final String postId;

  @override
  AsyncValue<Post> build() {
    ref.watch(sessionUserIdProvider);
    for (final scope in PostsScope.values) {
      final provider = postsFeedProvider(scope);
      if (!ref.exists(provider)) continue;
      for (final p in ref.read(provider).posts) {
        if (p.id == postId) return AsyncData(p);
      }
    }
    Future.microtask(reload);
    return const AsyncLoading();
  }

  Future<void> reload() async {
    final repo = ref.read(postsRepositoryProvider);
    if (repo == null) return;
    state = const AsyncLoading();
    try {
      final post = await repo.fetchPost(postId);
      if (ref.mounted) state = AsyncData(post);
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }

  void set(Post post) => state = AsyncData(post);
}

final postDetailProvider = NotifierProvider.autoDispose
    .family<PostDetailNotifier, AsyncValue<Post>, String>(
      PostDetailNotifier.new,
    );

// ---------------------------------------------------------------------------
// Actions shared by the feed, detail and composer screens
// ---------------------------------------------------------------------------

/// Thrown when an action needs a signed-in member.
class PostsSignInRequired implements Exception {
  const PostsSignInRequired();
}

class PostActions {
  PostActions(this._ref);

  final Ref _ref;
  final Set<String> _reacting = {};

  PostsRepository? get _repo => _ref.read(postsRepositoryProvider);

  bool isReacting(String postId) => _reacting.contains(postId);

  /// Shows [post] everywhere it is on screen (feed, my posts, detail).
  void sync(Post post) {
    for (final scope in PostsScope.values) {
      final provider = postsFeedProvider(scope);
      if (_ref.exists(provider)) _ref.read(provider.notifier).replace(post);
    }
    final detail = postDetailProvider(post.id);
    if (_ref.exists(detail)) _ref.read(detail.notifier).set(post);
  }

  /// Sets the member's reaction (null removes it). Shown at once and put
  /// back if the request fails. Returns false on failure or when a request
  /// for this post is still running (repeated taps are ignored).
  Future<bool> react(Post post, PostReaction? reaction) async {
    final repo = _repo;
    if (repo == null || _reacting.contains(post.id)) return false;
    if (post.myReaction == reaction) return true;
    _reacting.add(post.id);
    sync(post.withReaction(reaction));
    try {
      await repo.setReaction(postId: post.id, reaction: reaction);
      return true;
    } catch (_) {
      sync(post);
      return false;
    } finally {
      _reacting.remove(post.id);
    }
  }

  /// Creates a post as the signed-in member and adds it to the open lists.
  Future<Post> create({
    required String text,
    required List<NewPostImage> images,
    List<PostAttachment> attachments = const [],
  }) async {
    final repo = _repo;
    if (repo == null) throw StateError('Posts are not available');
    final author = postAuthorFrom(_ref.read(authProvider).user);
    if (author == null) throw const PostsSignInRequired();
    final post = await repo.createPost(
      author: author,
      text: text,
      images: images,
      attachments: attachments,
    );
    for (final scope in PostsScope.values) {
      final provider = postsFeedProvider(scope);
      if (_ref.exists(provider)) {
        _ref.read(provider.notifier).insertCreated(post);
      }
    }
    return post;
  }

  final Set<String> _deleting = {};

  /// True when the signed-in member wrote [post].
  bool isMine(Post post) {
    final me = _ref.read(sessionUserIdProvider);
    return me != null && me == post.author.id;
  }

  /// Deletes the member's own [post] and removes it from the open lists.
  /// Not optimistic: the post stays until the delete succeeds. Repeated
  /// calls while one is running are ignored (returns false).
  Future<bool> delete(Post post) async {
    final repo = _repo;
    if (repo == null) throw StateError('Posts are not available');
    if (!isMine(post)) throw StateError('Only the author can delete a post');
    if (!_deleting.add(post.id)) return false;
    try {
      await repo.deletePost(post.id);
      for (final scope in PostsScope.values) {
        final provider = postsFeedProvider(scope);
        if (_ref.exists(provider)) _ref.read(provider.notifier).remove(post.id);
      }
      return true;
    } finally {
      _deleting.remove(post.id);
    }
  }
}

final postActionsProvider = Provider<PostActions>(PostActions.new);

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

class PostCommentsState {
  const PostCommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.isSending = false,
  });

  final List<PostComment> comments;
  final bool isLoading;
  final Object? error;
  final bool isSending;

  PostCommentsState copyWith({
    List<PostComment>? comments,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    bool? isSending,
  }) => PostCommentsState(
    comments: comments ?? this.comments,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    isSending: isSending ?? this.isSending,
  );
}

class PostCommentsNotifier extends Notifier<PostCommentsState> {
  PostCommentsNotifier(this.postId);

  final String postId;

  @override
  PostCommentsState build() {
    ref.watch(sessionUserIdProvider);
    if (ref.watch(postsRepositoryProvider) == null) {
      return const PostCommentsState();
    }
    Future.microtask(load);
    return const PostCommentsState(isLoading: true);
  }

  Future<void> load() async {
    final repo = ref.read(postsRepositoryProvider);
    if (repo == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final comments = await repo.fetchComments(postId);
      if (ref.mounted) {
        state = state.copyWith(comments: comments, isLoading: false);
      }
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Sends [text] as the signed-in member. Returns null on success, or the
  /// error to show (the caller keeps the typed text). Ignored while another
  /// comment is being sent.
  Future<Object?> add(String text) async {
    final repo = ref.read(postsRepositoryProvider);
    final trimmed = text.trim();
    if (repo == null || trimmed.isEmpty || state.isSending) {
      return StateError('Nothing to send');
    }
    final author = postAuthorFrom(ref.read(authProvider).user);
    if (author == null) return const PostsSignInRequired();
    state = state.copyWith(isSending: true);
    try {
      final comment = await repo.addComment(
        postId: postId,
        author: author,
        text: trimmed,
      );
      if (!ref.mounted) return null;
      final comments = [...state.comments, comment];
      state = state.copyWith(comments: comments, isSending: false);
      final detailProvider = postDetailProvider(postId);
      final detail = ref.exists(detailProvider)
          ? ref.read(detailProvider).value
          : null;
      if (detail != null) {
        ref
            .read(postActionsProvider)
            .sync(detail.withCommentCount(detail.commentCount + 1));
      }
      return null;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(isSending: false);
      return e;
    }
  }
}

final postCommentsProvider = NotifierProvider.autoDispose
    .family<PostCommentsNotifier, PostCommentsState, String>(
      PostCommentsNotifier.new,
    );
