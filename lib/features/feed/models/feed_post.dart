class PostComment {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'User',
      authorAvatar: json['author_avatar']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author_name': authorName,
    'author_avatar': authorAvatar,
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };
}

class FeedPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorHeadline;
  final String content;
  final String mediaUrl;
  final String mediaType; // 'image', 'pdf', 'none'
  final String documentName;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final String userReaction; // 'like', 'celebrate', 'support', 'love', ''
  final DateTime createdAt;
  final List<PostComment> comments;

  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorHeadline,
    required this.content,
    this.mediaUrl = '',
    this.mediaType = 'none',
    this.documentName = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.userReaction = '',
    required this.createdAt,
    this.comments = const [],
  });

  FeedPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorHeadline,
    String? content,
    String? mediaUrl,
    String? mediaType,
    String? documentName,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    String? userReaction,
    DateTime? createdAt,
    List<PostComment>? comments,
  }) {
    return FeedPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorHeadline: authorHeadline ?? this.authorHeadline,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      documentName: documentName ?? this.documentName,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      userReaction: userReaction ?? this.userReaction,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
    );
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Member',
      authorAvatar: json['author_avatar']?.toString() ?? '',
      authorHeadline: json['author_headline']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'none',
      documentName: json['document_name']?.toString() ?? '',
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      userReaction: json['user_reaction']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      comments: json['comments'] != null && json['comments'] is List
          ? (json['comments'] as List)
                .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author_id': authorId,
    'author_name': authorName,
    'author_avatar': authorAvatar,
    'author_headline': authorHeadline,
    'content': content,
    'media_url': mediaUrl,
    'media_type': mediaType,
    'document_name': documentName,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'shares_count': sharesCount,
    'user_reaction': userReaction,
    'created_at': createdAt.toIso8601String(),
    'comments': comments.map((c) => c.toJson()).toList(),
  };
}
