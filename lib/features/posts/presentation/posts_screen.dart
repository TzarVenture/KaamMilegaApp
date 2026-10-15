import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/presentation/widgets/home_section_header.dart';
import '../providers/posts_provider.dart';
import '../repositories/posts_repository.dart';
import 'posts_access.dart';
import 'widgets/post_basics.dart';
import 'widgets/post_card.dart';

/// Posts: the community feed and "My posts" (opened from the + button,
/// the side menu, or after creating a post).
class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postsRepositoryProvider);
    final available = repo != null;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          title: const Text(
            'Posts',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: available
              ? const TabBar(
                  indicatorColor: AppColors.brandOrange,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AppColors.white,
                  unselectedLabelColor: Color(0xB3FFFFFF),
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(text: 'Feed'),
                    Tab(text: 'My posts'),
                  ],
                )
              : null,
        ),
        body: available
            ? const TabBarView(
                children: [
                  PostsList(scope: PostsScope.feed),
                  _MyPostsTab(),
                ],
              )
            : const PostsUnavailableView(),
      ),
    );
  }
}

/// Shown while the backend has no posts API (DEMO preview off).
class PostsUnavailableView extends StatelessWidget {
  const PostsUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    return const NetworkStateView(
      isEmpty: true,
      emptyTitle: 'Posts are coming soon',
      emptyMessage:
          'Sharing updates with the KaamMilega community will be available '
          'here soon.',
      child: SizedBox.shrink(),
    );
  }
}

class _MyPostsTab extends ConsumerWidget {
  const _MyPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AuthGuard.isSignedIn(ref.watch(authProvider))) {
      return const PostsList(scope: PostsScope.mine);
    }
    return NetworkStateView(
      isEmpty: true,
      emptyTitle: 'Log in to see your posts',
      emptyMessage: 'Your posts will appear here after you log in.',
      emptyAction: FilledButton(
        onPressed: () => context.push('/login'),
        child: const Text('Log in'),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

/// A scrollable, refreshable, paginated list of posts.
class PostsList extends ConsumerWidget {
  const PostsList({super.key, required this.scope});

  final PostsScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = postsFeedProvider(scope);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    // A refresh failed while posts are shown: keep them and say so.
    ref.listen(provider.select((s) => s.error), (previous, next) {
      if (next == null || previous != null) return;
      if (ref.read(provider).posts.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not refresh. ${postsErrorMessage(next)}'),
          ),
        );
    });

    final posts = state.posts;
    final firstLoadError = posts.isEmpty ? state.error : null;
    final header = <Widget>[
      if (scope == PostsScope.feed) const _StartPostCard(),
    ];

    return RefreshIndicator(
      color: AppColors.brandOrange,
      onRefresh: notifier.refresh,
      child: NetworkStateView(
        isLoading: state.isLoading && posts.isEmpty,
        loadingWidget: const PostsSkeletonList(),
        isOffline: firstLoadError is AppNetworkException,
        errorMessage: firstLoadError == null
            ? null
            : postsErrorMessage(firstLoadError),
        onRetry: notifier.refresh,
        isEmpty: posts.isEmpty,
        emptyTitle: scope == PostsScope.feed
            ? 'No posts yet'
            : 'You have not posted yet',
        emptyMessage: scope == PostsScope.feed
            ? 'Be the first to share an update with the community.'
            : 'Share an achievement, a tip or a question with the community.',
        emptyAction: FilledButton.icon(
          onPressed: () => openPostComposer(context, ref, openFeedAfter: false),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Create a post'),
        ),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: header.length + posts.length + 1,
          itemBuilder: (context, index) {
            if (index < header.length) return header[index];
            final i = index - header.length;
            if (i < posts.length) {
              final post = posts[i];
              return PostCard(
                key: ValueKey(post.id),
                post: post,
                onOpen: () => context.push('/posts/${post.id}'),
                onComment: () => context.push('/posts/${post.id}?comment=1'),
              );
            }
            return _ListFooter(state: state, onLoadMore: notifier.loadMore);
          },
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.onLoadMore});

  final PostsFeedState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Text(
              postsErrorMessage(state.loadMoreError!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.hasMore) {
      // Shown when the user scrolls near the end: load the next page.
      if (!state.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
      }
      return const PostCardSkeleton(withImage: false);
    }
    if (state.posts.isEmpty) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          "You're all caught up",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

/// "Start a post" prompt at the top of the feed.
class _StartPostCard extends ConsumerWidget {
  const _StartPostCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = postAuthorFrom(ref.watch(authProvider).user);
    final signedIn = AuthGuard.isSignedIn(ref.watch(authProvider));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: HomeCardShadow(
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(HomeCard.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openPostComposer(context, ref, openFeedAfter: false),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (signedIn && author != null)
                    PostAuthorAvatar(author: author, size: 40)
                  else
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Start a post',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.moduleSkills,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
