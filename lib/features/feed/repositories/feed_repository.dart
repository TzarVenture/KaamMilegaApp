import '../../../core/network/api_client.dart';
import '../models/feed_post.dart';

class FeedRepository {
  final ApiClient _apiClient;

  FeedRepository(this._apiClient);

  static final List<FeedPost> _fallbackPosts = [
    FeedPost(
      id: 'post_101',
      authorId: 'usr_201',
      authorName: 'Sunil Verma',
      authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=250',
      authorHeadline: 'Senior Logistics Specialist & Delivery Lead | Mumbai',
      content: '🚀 Excited to announce our logistics team in Mumbai successfully completed 5,000+ instant gig dispatches this month on KaamMilega! Looking for skilled delivery drivers & warehouse operations staff to join our expanding team.',
      mediaUrl: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&q=80&w=800',
      mediaType: 'image',
      likesCount: 42,
      commentsCount: 8,
      sharesCount: 3,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      comments: [
        PostComment(
          id: 'c1',
          authorName: 'Priya Sharma',
          authorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=150',
          content:
              'Congratulations Sunil! Interested in joining as warehouse lead.',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        PostComment(
          id: 'c2',
          authorName: 'Amit Patel',
          authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=150',
          content: 'Great milestone! Sending candidate profiles over.',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
    FeedPost(
      id: 'post_102',
      authorId: 'usr_202',
      authorName: 'KaamMilega HR Team',
      authorAvatar: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=250',
      authorHeadline: 'Official Recruitment & Hiring Portal',
      content: '💡 Hiring Alert: Over 120+ Verified Employers across Mumbai, Pune, and Delhi are actively recruiting today on KaamMilega! Upload your resume and verify your mobile number to get up to 14x more recruiter views.',
      mediaUrl: '',
      mediaType: 'none',
      likesCount: 89,
      commentsCount: 14,
      sharesCount: 19,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    FeedPost(
      id: 'post_103',
      authorId: 'usr_203',
      authorName: 'Rahul Deshmukh',
      authorAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=250',
      authorHeadline: 'Full-Stack Mobile Engineer & Flutter Specialist',
      content: '📄 Attached is our latest 2026 Blue-Collar & Tech Career Growth Guide PDF for job seekers in India. Contains tips on interviewing with top recruiters, salary negotiation, and resume optimization!',
      mediaUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      mediaType: 'pdf',
      documentName: 'KaamMilega_Career_Growth_Guide_2026.pdf',
      likesCount: 64,
      commentsCount: 5,
      sharesCount: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Get feed posts with fallback memory store
  Future<List<FeedPost>> getFeedPosts() async {
    try {
      final res = await _apiClient.get('/feed');
      if (res.data != null && res.data['posts'] is List) {
        final list = (res.data['posts'] as List)
            .map((item) => FeedPost.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return List.from(_fallbackPosts);
  }

  /// Create a new post
  Future<FeedPost> createPost({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String authorHeadline,
    required String content,
    String mediaUrl = '',
    String mediaType = 'none',
    String documentName = '',
  }) async {
    final newPost = FeedPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName.isNotEmpty ? authorName : 'Candidate User',
      authorAvatar: authorAvatar,
      authorHeadline: authorHeadline.isNotEmpty
          ? authorHeadline
          : 'Candidate on KaamMilega',
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      documentName: documentName,
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      createdAt: DateTime.now(),
    );

    try {
      await _apiClient.post('/posts', data: newPost.toJson());
    } catch (_) {}

    _fallbackPosts.insert(0, newPost);
    return newPost;
  }
}
