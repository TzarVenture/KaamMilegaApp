import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Reactions a member can leave on a post (one per member).
enum PostReaction {
  like('Like'),
  celebrate('Celebrate'),
  support('Support'),
  love('Love'),
  insightful('Insightful');

  const PostReaction(this.label);
  final String label;
}

/// The member who wrote a post or comment.
class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.name,
    this.headline = '',
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String headline;
  final String avatarUrl;
}

/// One image of a post: a server URL, a bundled asset (demo only) or bytes
/// picked on this device (demo only, never uploaded).
class PostImage {
  const PostImage.network(String this.url) : assetPath = null, bytes = null;
  const PostImage.asset(String this.assetPath) : url = null, bytes = null;
  const PostImage.memory(Uint8List this.bytes) : url = null, assetPath = null;

  final String? url;
  final String? assetPath;
  final Uint8List? bytes;

  ImageProvider<Object> get provider {
    if (bytes != null) return MemoryImage(bytes!);
    if (assetPath != null) return AssetImage(assetPath!);
    return CachedNetworkImageProvider(url!);
  }
}

/// An image picked in the composer, before the post is created.
class NewPostImage {
  const NewPostImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// A file attached to a post (PDF). [bytes] is set only for a file picked
/// on this device (DEMO preview; never uploaded); [url] for a server file.
class PostAttachment {
  const PostAttachment({
    required this.name,
    required this.sizeBytes,
    this.url,
    this.bytes,
  });

  final String name;
  final int sizeBytes;
  final String? url;
  final Uint8List? bytes;

  /// "245 KB", "1.4 MB".
  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    final kb = (sizeBytes / 1024).ceil();
    return '${kb < 1 ? 1 : kb} KB';
  }
}

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.images = const [],
    this.attachments = const [],
    this.reactionCounts = const {},
    this.myReaction,
    this.commentCount = 0,
    this.isDemo = false,
  });

  final String id;
  final PostAuthor author;
  final String text;
  final List<PostImage> images;

  /// PDF documents attached to the post.
  final List<PostAttachment> attachments;
  final DateTime createdAt;
  final Map<PostReaction, int> reactionCounts;

  /// The signed-in member's reaction, or null.
  final PostReaction? myReaction;
  final int commentCount;

  /// True for local DEMO preview content (never from or sent to the server).
  final bool isDemo;

  int get reactionTotal => reactionCounts.values.fold(0, (a, b) => a + b);

  /// Up to three reactions with the highest counts (for the summary icons).
  List<PostReaction> get topReactions {
    final entries = reactionCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries.take(3)) e.key];
  }

  /// This post after the signed-in member sets [next] (null removes it).
  Post withReaction(PostReaction? next) {
    if (next == myReaction) return this;
    final counts = Map<PostReaction, int>.of(reactionCounts);
    final previous = myReaction;
    if (previous != null) {
      final left = (counts[previous] ?? 0) - 1;
      if (left > 0) {
        counts[previous] = left;
      } else {
        counts.remove(previous);
      }
    }
    if (next != null) counts[next] = (counts[next] ?? 0) + 1;
    return _copy(reactionCounts: Map.unmodifiable(counts), myReaction: next);
  }

  Post withCommentCount(int count) => _copy(
    reactionCounts: reactionCounts,
    myReaction: myReaction,
    comments: count,
  );

  Post _copy({
    required Map<PostReaction, int> reactionCounts,
    required PostReaction? myReaction,
    int? comments,
  }) => Post(
    id: id,
    author: author,
    text: text,
    createdAt: createdAt,
    images: images,
    attachments: attachments,
    reactionCounts: reactionCounts,
    myReaction: myReaction,
    commentCount: comments ?? commentCount,
    isDemo: isDemo,
  );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.text,
    required this.createdAt,
    this.isDemo = false,
  });

  final String id;
  final String postId;
  final PostAuthor author;
  final String text;
  final DateTime createdAt;
  final bool isDemo;
}

/// One page of posts.
class PostsPage {
  const PostsPage({required this.posts, required this.hasMore});

  final List<Post> posts;
  final bool hasMore;
}
