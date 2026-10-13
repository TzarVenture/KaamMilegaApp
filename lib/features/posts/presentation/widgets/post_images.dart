import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/post.dart';

/// Post photos laid out for 1, 2, 3 or 4+ images (full card width). Images
/// are decoded at the size they are shown, not at full resolution.
class PostImageGrid extends StatelessWidget {
  const PostImageGrid({super.key, required this.images});

  final List<PostImage> images;

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final half = (w - _gap) / 2;
        Widget tile(int i, double tileWidth, {int extra = 0}) => _PhotoTile(
          images: images,
          index: i,
          decodeWidth: tileWidth,
          extra: extra,
        );

        switch (images.length) {
          case 1:
            return AspectRatio(aspectRatio: 4 / 3, child: tile(0, w));
          case 2:
            return SizedBox(
              height: half,
              child: Row(
                children: [
                  Expanded(child: tile(0, half)),
                  const SizedBox(width: _gap),
                  Expanded(child: tile(1, half)),
                ],
              ),
            );
          case 3:
            return SizedBox(
              height: w * 0.66,
              child: Row(
                children: [
                  Expanded(flex: 2, child: tile(0, w * 0.66)),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: tile(1, w / 3)),
                        const SizedBox(height: _gap),
                        Expanded(child: tile(2, w / 3)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          default:
            return SizedBox(
              height: w,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: tile(0, half)),
                        const SizedBox(width: _gap),
                        Expanded(child: tile(1, half)),
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: tile(2, half)),
                        const SizedBox(width: _gap),
                        Expanded(
                          child: tile(3, half, extra: images.length - 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.images,
    required this.index,
    required this.decodeWidth,
    this.extra = 0,
  });

  final List<PostImage> images;
  final int index;
  final double decodeWidth;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (decodeWidth * dpr).round().clamp(1, 2048);
    return Semantics(
      button: true,
      image: true,
      label: 'Photo ${index + 1} of ${images.length}. Open full screen',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => openPostImageViewer(context, images, index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.skeleton,
              child: Image(
                image: ResizeImage.resizeIfNeeded(
                  cacheWidth,
                  null,
                  images[index].provider,
                ),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, sync) => sync
                    ? child
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 220),
                        child: child,
                      ),
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            if (extra > 0)
              ColoredBox(
                color: AppColors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen, zoomable, swipeable photo viewer.
Future<void> openPostImageViewer(
  BuildContext context,
  List<PostImage> images,
  int initialIndex,
) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          PostImageViewer(images: images, initialIndex: initialIndex),
    ),
  );
}

class PostImageViewer extends StatefulWidget {
  const PostImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<PostImage> images;
  final int initialIndex;

  @override
  State<PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<PostImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image(
                  image: widget.images[i].provider,
                  fit: BoxFit.contain,
                  semanticLabel: 'Photo ${i + 1} of $count',
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.white,
                    ),
                  ),
                  const Spacer(),
                  if (count > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_index + 1} / $count',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
