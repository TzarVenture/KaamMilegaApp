import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/app/auth_guard.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/posts/models/post.dart';
import 'package:kaam_milega/features/posts/presentation/post_composer_screen.dart';
import 'package:kaam_milega/features/posts/presentation/post_detail_screen.dart';
import 'package:kaam_milega/features/posts/presentation/posts_access.dart';
import 'package:kaam_milega/features/posts/presentation/posts_screen.dart';
import 'package:kaam_milega/features/posts/presentation/widgets/post_basics.dart';
import 'package:kaam_milega/features/posts/providers/post_image_picker.dart';
import 'package:kaam_milega/features/posts/providers/posts_provider.dart';
import 'package:kaam_milega/features/posts/repositories/demo_posts_repository.dart';
import 'package:kaam_milega/features/posts/repositories/posts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile _me() => UserProfile(
  id: 'me',
  mobile: '',
  name: 'Test Member',
  headline: 'Store Associate',
  isRegistered: true,
);

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => AuthState(isAuthenticated: true, user: _me());
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

/// Demo repository with call counters and injectable failures / pauses.
class _TestRepo extends DemoPostsRepository {
  _TestRepo({super.latency = Duration.zero});

  int fetchCalls = 0;
  int createCalls = 0;
  int reactCalls = 0;
  int commentCalls = 0;
  Object? fetchError;
  Object? createError;
  Object? reactError;
  Object? commentError;
  bool emptyFeed = false;
  Completer<void>? createGate;
  Completer<void>? reactGate;

  @override
  Future<PostsPage> fetchPosts({
    required PostsScope scope,
    required String? viewerId,
    required int page,
    required int pageSize,
  }) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    if (emptyFeed) return const PostsPage(posts: [], hasMore: false);
    return super.fetchPosts(
      scope: scope,
      viewerId: viewerId,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Post> createPost({
    required PostAuthor author,
    required String text,
    required List<NewPostImage> images,
    List<PostAttachment> attachments = const [],
  }) async {
    createCalls++;
    await createGate?.future;
    if (createError != null) throw createError!;
    return super.createPost(
      author: author,
      text: text,
      images: images,
      attachments: attachments,
    );
  }

  @override
  Future<void> setReaction({
    required String postId,
    required PostReaction? reaction,
  }) async {
    reactCalls++;
    await reactGate?.future;
    if (reactError != null) throw reactError!;
    return super.setReaction(postId: postId, reaction: reaction);
  }

  @override
  Future<PostComment> addComment({
    required String postId,
    required PostAuthor author,
    required String text,
  }) async {
    commentCalls++;
    if (commentError != null) throw commentError!;
    return super.addComment(postId: postId, author: author, text: text);
  }
}

// A valid 1x1 PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, //
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Stands in for the + button sheet: calls the same openPostComposer.
class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => openPostComposer(context, ref),
        child: const Text('Create a Post'),
      ),
    ),
  );
}

({ApiClient client, List<RequestOptions> sent}) _recordingClient() {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, handler) {
        sent.add(o);
        handler.reject(DioException(requestOptions: o));
      },
    ),
  );
  return (client: ApiClient(dio: dio), sent: sent);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required PostsRepository? repo,
  bool signedIn = true,
  String initial = '/posts',
  PostImagePicker? picker,
  PostPdfPicker? pdfPicker,
  ApiClient? apiClient,
}) async {
  // Tall phone so the first post's actions and the comments are on screen.
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (signedIn) await LocalStorage.saveToken('test-token');
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const _Launcher()),
      GoRoute(path: '/posts', builder: (_, _) => const PostsScreen()),
      GoRoute(
        path: '/posts/new',
        builder: (_, _) => const PostComposerScreen(),
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) => PostDetailScreen(
          postId: state.pathParameters['id']!,
          focusComment: state.uri.queryParameters['comment'] == '1',
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login page')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => signedIn ? _SignedIn() : _Guest()),
        postsRepositoryProvider.overrideWithValue(repo),
        if (picker != null) postImagePickerProvider.overrideWithValue(picker),
        if (pdfPicker != null)
          postPdfPickerProvider.overrideWithValue(pdfPicker),
        if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lets the providers' first load (scheduled in build) finish.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _container(PostsRepository repo) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authProvider.overrideWith(_SignedIn.new),
      postsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Finder _postButton() => find.widgetWithText(FilledButton, 'Post');

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('availability and DEMO isolation', () {
    test('debug builds use the local DEMO repository (temporary)', () {
      expect(kPostsDemoMode, isTrue);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(postsRepositoryProvider);
      expect(repo, isA<DemoPostsRepository>());
      expect(repo!.isDemo, isTrue);
    });

    test('the DEMO repository has no network access', () {
      final source = File(
        'lib/features/posts/repositories/demo_posts_repository.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('api_client')));
      expect(source, isNot(contains('package:dio')));
      expect(DemoPostsRepository().isDemo, isTrue);
    });

    testWidgets('Posts screen without an API says coming soon, no DEMO', (
      tester,
    ) async {
      await _pumpApp(tester, repo: null);
      expect(find.text('Posts are coming soon'), findsOneWidget);
      expect(find.text('DEMO'), findsNothing);
      expect(find.text('Feed'), findsNothing);
    });

    testWidgets('DEMO posting, reacting and commenting send no requests', (
      tester,
    ) async {
      final recorder = _recordingClient();
      final repo = _TestRepo();
      await _pumpApp(tester, repo: repo, apiClient: recorder.client);

      expect(find.text('DEMO'), findsNothing);

      await tester.tap(find.text('Like').first);
      await tester.pumpAndSettle();
      expect(repo.reactCalls, 1);

      await tester.tap(find.text('Comment').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nice update');
      await tester.pump();
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pumpAndSettle();
      expect(repo.commentCalls, 1);

      expect(recorder.sent, isEmpty);
    });
  });

  group('Create a Post from the + button', () {
    testWidgets('guest gets Login Required and no composer', (tester) async {
      final repo = _TestRepo();
      await _pumpApp(tester, repo: repo, signedIn: false, initial: '/home');

      await tester.tap(find.text('Create a Post'));
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsOneWidget);
      expect(find.text('Create a post'), findsNothing);
      expect(repo.createCalls, 0);
    });

    test('composer route needs a login', () {
      expect(AuthGuard.isProtected('/posts/new'), isTrue);
      expect(AuthGuard.isProtected('/posts'), isFalse);
    });

    testWidgets('without a posts API nothing is posted', (tester) async {
      await _pumpApp(tester, repo: null, initial: '/home');

      await tester.tap(find.text('Create a Post'));
      await tester.pumpAndSettle();

      expect(
        find.text('Posts are coming soon. Nothing has been posted.'),
        findsOneWidget,
      );
      expect(find.text('Create a post'), findsNothing);
    });

    testWidgets('signed in: add / remove photos, post once, feed shows it', (
      tester,
    ) async {
      final repo = _TestRepo()..createGate = Completer<void>();
      await _pumpApp(
        tester,
        repo: repo,
        initial: '/home',
        picker: ({required int limit}) async => [
          NewPostImage(name: 'a.png', bytes: _png),
          NewPostImage(name: 'b.png', bytes: _png),
        ],
      );

      await tester.tap(find.text('Create a Post'));
      await tester.pumpAndSettle();
      expect(find.text('Create a post'), findsOneWidget);
      expect(find.text('Test Member'), findsOneWidget);

      // Empty draft cannot be posted.
      expect(tester.widget<FilledButton>(_postButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'My first post');
      await tester.tap(find.textContaining('Add photos'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove photo 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove photo 2'));
      await tester.pump();
      expect(find.byTooltip('Remove photo 2'), findsNothing);
      expect(find.text('Add photos (1/4)'), findsOneWidget);

      // Double tap while the request runs: one request only.
      await tester.tap(_postButton());
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      repo.createGate!.complete();
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('My first post'), findsOneWidget);
    });

    testWidgets('a failed post keeps the draft and explains the error', (
      tester,
    ) async {
      final repo = _TestRepo()..createError = const AppNetworkException();
      await _pumpApp(tester, repo: repo, initial: '/posts/new');

      await tester.enterText(find.byType(TextField), 'Keep this text');
      await tester.pump();
      await tester.tap(_postButton());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your post was not published'),
        findsOneWidget,
      );
      expect(find.text('Keep this text'), findsOneWidget);
      expect(find.text('Create a post'), findsOneWidget);
    });

    testWidgets('cancelled or oversized photo picks add nothing', (
      tester,
    ) async {
      var result = <NewPostImage>[];
      await _pumpApp(
        tester,
        repo: _TestRepo(),
        initial: '/posts/new',
        picker: ({required int limit}) async => result,
      );

      await tester.tap(find.textContaining('Add photos'));
      await tester.pumpAndSettle();
      expect(find.text('Add photos (0/4)'), findsOneWidget);

      result = [
        NewPostImage(
          name: 'big.jpg',
          bytes: Uint8List(PostComposerScreen.maxImageBytes + 1),
        ),
      ];
      await tester.tap(find.textContaining('Add photos'));
      await tester.pumpAndSettle();
      expect(find.text('Add photos (0/4)'), findsOneWidget);
      expect(
        find.text('Photos larger than 10 MB were not added.'),
        findsOneWidget,
      );
    });
  });

  group('feed states', () {
    testWidgets('shows skeletons while loading, then posts', (tester) async {
      final repo = _TestRepo(latency: const Duration(milliseconds: 300));
      await LocalStorage.saveToken('test-token');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_SignedIn.new),
            postsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PostCardSkeleton), findsWidgets);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Ananya Rao'), findsWidgets);
    });

    testWidgets('empty feed', (tester) async {
      await _pumpApp(tester, repo: _TestRepo()..emptyFeed = true);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('error with Retry (not shown as empty)', (tester) async {
      final repo = _TestRepo()..fetchError = const AppServerException();
      await _pumpApp(tester, repo: repo);

      expect(find.text('No posts yet'), findsNothing);
      expect(
        find.textContaining('Server is temporarily unavailable'),
        findsOneWidget,
      );

      repo.fetchError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Ananya Rao'), findsWidgets);
    });

    testWidgets('guest can read but reacting asks to log in', (tester) async {
      final repo = _TestRepo();
      await _pumpApp(tester, repo: repo, signedIn: false);

      expect(find.text('Ananya Rao'), findsWidgets);
      await tester.tap(find.text('Like').first);
      await tester.pumpAndSettle();

      expect(find.text('Login Required'), findsOneWidget);
      expect(repo.reactCalls, 0);
    });

    test('pagination loads the next page once, without duplicates', () async {
      final container = _container(_TestRepo());
      final provider = postsFeedProvider(PostsScope.feed);
      container.listen(provider, (_, _) {});
      await _settle();

      expect(container.read(provider).posts, hasLength(10));
      expect(container.read(provider).hasMore, isTrue);

      await Future.wait([
        container.read(provider.notifier).loadMore(),
        container.read(provider.notifier).loadMore(),
      ]);
      final posts = container.read(provider).posts;
      expect(posts, hasLength(12));
      expect(posts.map((p) => p.id).toSet(), hasLength(12));
      expect(container.read(provider).hasMore, isFalse);
    });
  });

  group('reactions', () {
    test('Post.withReaction updates counts', () {
      final post = Post(
        id: 'p',
        author: const PostAuthor(id: 'a', name: 'A'),
        text: 't',
        createdAt: DateTime(2026),
        reactionCounts: const {PostReaction.like: 2},
      );
      final liked = post.withReaction(PostReaction.like);
      expect(liked.reactionTotal, 3);
      final changed = liked.withReaction(PostReaction.love);
      expect(changed.reactionCounts[PostReaction.like], 2);
      expect(changed.reactionCounts[PostReaction.love], 1);
      final removed = changed.withReaction(null);
      expect(removed.reactionTotal, 2);
      expect(removed.myReaction, isNull);
    });

    test('shown at once, rolled back when the request fails', () async {
      final repo = _TestRepo()..reactError = const AppNetworkException();
      final container = _container(repo);
      final provider = postsFeedProvider(PostsScope.feed);
      container.listen(provider, (_, _) {});
      await _settle();
      final before = container.read(provider).posts.first;

      final ok = await container
          .read(postActionsProvider)
          .react(before, PostReaction.like);

      expect(ok, isFalse);
      final after = container.read(provider).posts.first;
      expect(after.myReaction, isNull);
      expect(after.reactionTotal, before.reactionTotal);
    });

    test('success keeps the reaction; repeated taps are ignored', () async {
      final repo = _TestRepo()..reactGate = Completer<void>();
      final container = _container(repo);
      final provider = postsFeedProvider(PostsScope.feed);
      container.listen(provider, (_, _) {});
      await _settle();
      final post = container.read(provider).posts.first;
      final actions = container.read(postActionsProvider);

      final first = actions.react(post, PostReaction.celebrate);
      expect(
        container.read(provider).posts.first.myReaction,
        PostReaction.celebrate,
      );
      expect(await actions.react(post, PostReaction.celebrate), isFalse);
      repo.reactGate!.complete();
      expect(await first, isTrue);

      expect(repo.reactCalls, 1);
      final now = container.read(provider).posts.first;
      expect(now.myReaction, PostReaction.celebrate);
      expect(now.reactionTotal, post.reactionTotal + 1);
    });
  });

  group('comments', () {
    testWidgets('lists comments and adds one (count updates)', (tester) async {
      await _pumpApp(tester, repo: _TestRepo(), initial: '/posts/demo-post-1');

      expect(find.text('Congratulations! Well deserved.'), findsOneWidget);
      expect(find.text('Comments (2)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Great work');
      await tester.pump();
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pumpAndSettle();

      expect(find.text('Great work'), findsOneWidget);
      expect(find.text('Comments (3)'), findsOneWidget);
    });

    testWidgets('failed comment keeps the text', (tester) async {
      final repo = _TestRepo()..commentError = const AppNetworkException();
      await _pumpApp(tester, repo: repo, initial: '/posts/demo-post-1');

      await tester.enterText(find.byType(TextField), 'Try again later');
      await tester.pump();
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Comment not posted'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
      expect(find.text('Comments (2)'), findsOneWidget);
    });

    testWidgets('guest sees comments but must log in to comment', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        repo: _TestRepo(),
        signedIn: false,
        initial: '/posts/demo-post-1',
      );

      expect(find.text('Congratulations! Well deserved.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Log in to comment'));
      await tester.pumpAndSettle();
      expect(find.text('Login Required'), findsOneWidget);
    });
  });

  group('PDF attachments', () {
    testWidgets('attach a PDF, remove it, attach again and post it', (
      tester,
    ) async {
      final repo = _TestRepo();
      await _pumpApp(
        tester,
        repo: repo,
        initial: '/home',
        pdfPicker: () async => PostAttachment(
          name: 'Guide.pdf',
          sizeBytes: 2048,
          bytes: Uint8List(2048),
        ),
      );
      await tester.tap(find.text('Create a Post'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add PDF'));
      await tester.pumpAndSettle();
      expect(find.text('Guide.pdf'), findsOneWidget);
      expect(find.text('PDF added'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove PDF'));
      await tester.pump();
      expect(find.text('Guide.pdf'), findsNothing);

      await tester.tap(find.text('Add PDF'));
      await tester.pumpAndSettle();
      // A PDF alone is enough to post.
      expect(tester.widget<FilledButton>(_postButton()).onPressed, isNotNull);
      await tester.tap(_postButton());
      await tester.pumpAndSettle();

      expect(repo.createCalls, 1);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Guide.pdf'), findsOneWidget);
    });

    testWidgets('PDFs over 10 MB are refused', (tester) async {
      await _pumpApp(
        tester,
        repo: _TestRepo(),
        initial: '/posts/new',
        pdfPicker: () async => PostAttachment(
          name: 'Big.pdf',
          sizeBytes: PostComposerScreen.maxPdfBytes + 1,
        ),
      );
      await tester.tap(find.text('Add PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Big.pdf'), findsNothing);
      expect(
        find.text('PDFs larger than 10 MB cannot be attached.'),
        findsOneWidget,
      );
    });
  });

  group('delete own post', () {
    testWidgets('only my post has the menu; delete asks, then removes it', (
      tester,
    ) async {
      final repo = _TestRepo();
      await repo.createPost(
        author: const PostAuthor(id: 'me', name: 'Test Member'),
        text: 'Mine to delete',
        images: const [],
      );
      await _pumpApp(tester, repo: repo);

      expect(find.text('Mine to delete'), findsOneWidget);
      expect(find.byTooltip('Post options'), findsOneWidget);

      await tester.tap(find.byTooltip('Post options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete post'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this post?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Mine to delete'), findsNothing);
      expect(find.text('Post deleted.'), findsOneWidget);
    });

    test('someone else\'s post cannot be deleted', () async {
      final container = _container(_TestRepo());
      final provider = postsFeedProvider(PostsScope.feed);
      container.listen(provider, (_, _) {});
      await _settle();
      final others = container.read(provider).posts.first;

      expect(container.read(postActionsProvider).isMine(others), isFalse);
      await expectLater(
        container.read(postActionsProvider).delete(others),
        throwsStateError,
      );
      expect(container.read(provider).posts.first.id, others.id);
    });
  });
}
