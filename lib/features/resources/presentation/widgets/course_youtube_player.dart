import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Builds the in-app video player for a YouTube video id. Replaced in tests
/// (the real player needs a platform web view).
typedef CourseVideoPlayerBuilder = Widget Function(String videoId);

final courseVideoPlayerProvider = Provider<CourseVideoPlayerBuilder>(
  (ref) =>
      (videoId) => CourseYoutubePlayer(videoId: videoId),
);

/// YouTube's own embedded player (play, seek, quality, full screen),
/// started automatically. Rotating the phone or the full-screen button
/// switches to full screen.
class CourseYoutubePlayer extends StatefulWidget {
  const CourseYoutubePlayer({super.key, required this.videoId});

  final String videoId;

  /// YouTube refuses embedded playback (errors 152 / 153) when the player
  /// page has no proper origin; an https origin from the app id fixes it.
  static const String origin = 'https://com.kaammilega.app';

  @override
  State<CourseYoutubePlayer> createState() => _CourseYoutubePlayerState();
}

class _CourseYoutubePlayerState extends State<CourseYoutubePlayer> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          origin: CourseYoutubePlayer.origin,
          showFullscreenButton: true,
        ),
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
  }
}
