import '../models/post.dart';
import 'posts_repository.dart';

/// DEMO ONLY: local, in-memory posts for previewing the Posts screens while
/// the backend has no posts API.
///
/// - Used only when [kPostsDemoMode] is on (never in release builds).
/// - Never calls the network: nothing here is sent to or read from the
///   KaamMilega backend, and picked images are never uploaded.
/// - Every post and comment is marked [Post.isDemo] and shown with a DEMO
///   label. The people below are fictional.
/// - Data is lost when the app restarts.
class DemoPostsRepository implements PostsRepository {
  DemoPostsRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime? now,
  }) {
    _seed(now ?? DateTime.now());
  }

  /// Simulated wait so loading states can be previewed.
  final Duration latency;

  final List<Post> _posts = [];
  final Map<String, List<PostComment>> _comments = {};
  int _seq = 0;

  @override
  bool get isDemo => true;

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<PostsPage> fetchPosts({
    required PostsScope scope,
    required String? viewerId,
    required int page,
    required int pageSize,
  }) async {
    await _wait();
    final source = switch (scope) {
      PostsScope.feed => _posts,
      PostsScope.mine =>
        viewerId == null
            ? const <Post>[]
            : _posts.where((p) => p.author.id == viewerId).toList(),
    };
    final start = (page - 1) * pageSize;
    if (start >= source.length) {
      return const PostsPage(posts: [], hasMore: false);
    }
    final end = (start + pageSize).clamp(0, source.length);
    return PostsPage(
      posts: List.unmodifiable(source.sublist(start, end)),
      hasMore: end < source.length,
    );
  }

  @override
  Future<Post> fetchPost(String postId) async {
    await _wait();
    return _find(postId);
  }

  @override
  Future<Post> createPost({
    required PostAuthor author,
    required String text,
    required List<NewPostImage> images,
    List<PostAttachment> attachments = const [],
  }) async {
    await _wait();
    final post = Post(
      id: 'demo-post-${++_seq}',
      author: author,
      text: text,
      createdAt: DateTime.now(),
      images: [for (final i in images) PostImage.memory(i.bytes)],
      attachments: List.unmodifiable(attachments),
      isDemo: true,
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<void> deletePost(String postId) async {
    await _wait();
    _posts.removeAt(_indexOf(postId));
    _comments.remove(postId);
  }

  @override
  Future<void> setReaction({
    required String postId,
    required PostReaction? reaction,
  }) async {
    await _wait();
    final index = _indexOf(postId);
    _posts[index] = _posts[index].withReaction(reaction);
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    await _wait();
    _find(postId);
    return List.unmodifiable(_comments[postId] ?? const []);
  }

  @override
  Future<PostComment> addComment({
    required String postId,
    required PostAuthor author,
    required String text,
  }) async {
    await _wait();
    final index = _indexOf(postId);
    final comment = PostComment(
      id: 'demo-comment-${++_seq}',
      postId: postId,
      author: author,
      text: text,
      createdAt: DateTime.now(),
      isDemo: true,
    );
    final list = _comments.putIfAbsent(postId, () => [])..add(comment);
    _posts[index] = _posts[index].withCommentCount(list.length);
    return comment;
  }

  Post _find(String postId) => _posts[_indexOf(postId)];

  int _indexOf(String postId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index < 0) throw StateError('Demo post $postId not found');
    return index;
  }

  // ---------------------------------------------------------------------
  // Fictional preview content.
  // ---------------------------------------------------------------------

  void _seed(DateTime now) {
    const people = [
      PostAuthor(
        id: 'demo-user-1',
        name: 'Ananya Rao',
        headline: 'Warehouse Supervisor, Pune',
      ),
      PostAuthor(
        id: 'demo-user-2',
        name: 'Rohit Verma',
        headline: 'Electrician | 6 years experience',
      ),
      PostAuthor(
        id: 'demo-user-3',
        name: 'Meera Iyer',
        headline: 'HR Executive, hiring for retail roles',
      ),
      PostAuthor(
        id: 'demo-user-4',
        name: 'Karan Singh',
        headline: 'Delivery Partner and part-time student',
      ),
      PostAuthor(
        id: 'demo-user-5',
        name: 'Sneha Patil',
        headline: 'Career mentor for first-time job seekers',
      ),
    ];

    final items =
        <
          (
            PostAuthor,
            String,
            List<PostImage>,
            Duration,
            Map<PostReaction, int>,
          )
        >[
          (
            people[0],
            'Completed my forklift safety certification today. Thank you to '
                'everyone who helped me prepare. If you are working in a '
                'warehouse, do not skip safety training. It makes the whole '
                'team faster and safer.',
            const [PostImage.asset('assets/images/skills_hero.webp')],
            const Duration(minutes: 42),
            {PostReaction.celebrate: 18, PostReaction.like: 11},
          ),
          (
            people[2],
            'We are hiring store associates and cashiers in three cities this '
                'month. Freshers are welcome. Keep your profile complete with '
                'your skills and preferred location so we can find you quickly.'
                '\n\nTips that help your application stand out:\n'
                '1. Add a clear profile photo.\n'
                '2. List languages you speak.\n'
                '3. Mention your available shift timings.\n'
                '4. Keep your phone number verified.',
            const [],
            const Duration(hours: 3),
            {PostReaction.like: 24, PostReaction.insightful: 9},
          ),
          (
            people[1],
            'Finished the wiring for a new community hall this week. Small '
                'jobs, big jobs, every project teaches something new.',
            const [
              PostImage.asset('assets/images/services_hero.webp'),
              PostImage.asset('assets/images/instant_work_hero.webp'),
              PostImage.asset('assets/images/events_hero.webp'),
            ],
            const Duration(hours: 9),
            {PostReaction.like: 7, PostReaction.support: 3},
          ),
          (
            people[4],
            'Interview tip: before you answer, take a short pause. It shows you '
                'are thinking, and it keeps your answer clear. Practise with a '
                'friend at least once before the real interview.',
            const [],
            const Duration(days: 1, hours: 2),
            {PostReaction.insightful: 31, PostReaction.love: 6},
          ),
          (
            people[3],
            'Six months ago I started delivery work to pay for my studies. This '
                'week I cleared my second-year exams. Grateful for flexible gigs.',
            const [PostImage.asset('assets/images/p2p_hero.webp')],
            const Duration(days: 2),
            {PostReaction.support: 14, PostReaction.celebrate: 12},
          ),
          (
            people[0],
            'Question for the community: which skills course helped you most '
                'in getting your first job? Share below.',
            const [],
            const Duration(days: 3),
            {PostReaction.like: 5},
          ),
          (
            people[4],
            'Free resume review session this Saturday for freshers. Bring one '
                'printed copy and a list of jobs you want to apply for.',
            const [PostImage.asset('assets/images/experts_hero.webp')],
            const Duration(days: 4),
            {PostReaction.like: 13, PostReaction.love: 2},
          ),
          (
            people[1],
            'Reminder: always switch off the main supply before any repair. No '
                'deadline is worth a shock.',
            const [],
            const Duration(days: 5),
            {PostReaction.insightful: 8},
          ),
          (
            people[2],
            'Thank you to all candidates who walked in for our hiring day. We '
                'will call everyone shortlisted by Friday.',
            const [],
            const Duration(days: 6),
            {PostReaction.like: 19},
          ),
          (
            people[3],
            'Rainy season delivery tip: keep a spare plastic sleeve for the '
                'phone and one for the parcels.',
            const [],
            const Duration(days: 8),
            {PostReaction.like: 4, PostReaction.support: 1},
          ),
          (
            people[0],
            'One year at my current company today. Started as a picker, now '
                'leading a team of eight.',
            const [],
            const Duration(days: 10),
            {PostReaction.celebrate: 40, PostReaction.love: 9},
          ),
          (
            people[4],
            'Your first job does not have to be your dream job. It has to teach '
                'you something. Keep learning.',
            const [],
            const Duration(days: 12),
            {PostReaction.love: 15, PostReaction.insightful: 10},
          ),
        ];

    for (final (author, text, images, age, counts) in items) {
      final id = 'demo-post-${++_seq}';
      _posts.add(
        Post(
          id: id,
          author: author,
          text: text,
          images: images,
          createdAt: now.subtract(age),
          reactionCounts: Map.unmodifiable(counts),
          isDemo: true,
        ),
      );
    }

    // Sample PDF attachments (names only; there is no file to open).
    _attach(1, 'Store_Associate_Job_Description.pdf', 182 * 1024);
    _attach(6, 'Resume_Checklist_for_Freshers.pdf', 248 * 1024);

    // A few comments on the first posts.
    _addSeedComment(
      _posts[0],
      people[4],
      'Congratulations! Well deserved.',
      now.subtract(const Duration(minutes: 30)),
    );
    _addSeedComment(
      _posts[0],
      people[1],
      'Safety first, always.',
      now.subtract(const Duration(minutes: 12)),
    );
    _addSeedComment(
      _posts[1],
      people[3],
      'Is there an opening for evening shifts?',
      now.subtract(const Duration(hours: 2)),
    );
    _addSeedComment(
      _posts[3],
      people[0],
      'Very useful, thank you.',
      now.subtract(const Duration(hours: 20)),
    );
  }

  void _attach(int index, String name, int size) {
    final p = _posts[index];
    _posts[index] = Post(
      id: p.id,
      author: p.author,
      text: p.text,
      images: p.images,
      attachments: [PostAttachment(name: name, sizeBytes: size)],
      createdAt: p.createdAt,
      reactionCounts: p.reactionCounts,
      commentCount: p.commentCount,
      isDemo: true,
    );
  }

  void _addSeedComment(Post post, PostAuthor author, String text, DateTime at) {
    final list = _comments.putIfAbsent(post.id, () => [])
      ..add(
        PostComment(
          id: 'demo-comment-${++_seq}',
          postId: post.id,
          author: author,
          text: text,
          createdAt: at,
          isDemo: true,
        ),
      );
    final index = _indexOf(post.id);
    _posts[index] = _posts[index].withCommentCount(list.length);
  }
}
