import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/shared/widgets/banner_image.dart';

Future<Size> _pump(
  WidgetTester tester,
  double width,
  VoidCallback onTap,
) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BannerImage(
              asset: 'assets/images/p2p_hero.webp',
              pixelWidth: 1080,
              pixelHeight: 721,
              semanticLabel: 'Connect. Share. Collaborate. Grow together.',
              onTap: onTap,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(
    find.descendant(
      of: find.byType(BannerImage),
      matching: find.byType(AspectRatio),
    ),
  );
}

void main() {
  const ratio = 1080 / 721;

  for (final width in [320.0, 360.0, 430.0, 600.0]) {
    testWidgets('Peer-to-peer banner fills $width px and keeps its shape', (
      tester,
    ) async {
      final size = await _pump(tester, width, () {});
      expect(tester.takeException(), isNull);
      expect(size.width, closeTo(width - 32, 0.5));
      expect(size.width / size.height, closeTo(ratio, 0.01));
    });
  }

  testWidgets('wide tablet: at most 720 wide', (tester) async {
    final size = await _pump(tester, 1000, () {});
    expect(size.width, closeTo(720, 0.5));
  });

  testWidgets('tapping the banner runs its action', (tester) async {
    var taps = 0;
    await _pump(tester, 360, () => taps++);
    await tester.tap(find.byType(BannerImage));
    expect(taps, 1);
  });
}
