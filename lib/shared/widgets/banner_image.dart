import 'package:flutter/material.dart';

/// A promo banner picture (with its text and button drawn in the image).
///
/// Fills the available width on every device and keeps the picture's
/// proportions, so a larger screen shows a proportionally larger banner.
/// On very wide screens it stops at [maxWidth] and is centred. Only as many
/// pixels as the screen shows are decoded. Tapping it runs [onTap].
class BannerImage extends StatelessWidget {
  const BannerImage({
    super.key,
    required this.asset,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.semanticLabel,
    this.onTap,
    this.maxWidth = 720,
    this.borderRadius = 0,
  });

  /// Asset path, for example `assets/images/events_hero.webp`.
  final String asset;

  /// The picture's size in pixels (sets the shape).
  final int pixelWidth;
  final int pixelHeight;

  /// What the banner says, read out by screen readers.
  final String semanticLabel;
  final VoidCallback? onTap;
  final double maxWidth;

  /// Rounds the picture's corners (for pictures drawn edge to edge).
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < maxWidth
                ? constraints.maxWidth
                : maxWidth;
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final decodeWidth = (width * dpr)
                .round()
                .clamp(1, pixelWidth)
                .toInt();
            return Center(
              child: SizedBox(
                width: width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: AspectRatio(
                    aspectRatio: pixelWidth / pixelHeight,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.fill,
                      cacheWidth: decodeWidth,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
