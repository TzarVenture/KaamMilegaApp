import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/splash/presentation/splash_screen.dart';

/// Splash entrance animation: finishes, and never overflows on small phones
/// or with large font settings.
void main() {
  Future<void> pumpSplash(
    WidgetTester tester, {
    required Size screen,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screen,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const SplashScreen(),
        ),
      ),
    );
    // Let the one-time entrance finish (the spinner keeps running, so
    // pumpAndSettle is not used).
    await tester.pump(const Duration(milliseconds: 1000));
  }

  testWidgets('shows tagline after the entrance on a normal phone', (
    tester,
  ) async {
    await pumpSplash(tester, screen: const Size(390, 844));
    expect(find.text('Kaam Bhi. Skill Bhi. Kamaai Bhi.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow on a small phone with large text', (tester) async {
    await pumpSplash(tester, screen: const Size(320, 480), textScale: 2.0);
    expect(find.text('Kaam Bhi. Skill Bhi. Kamaai Bhi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large phone renders normally', (tester) async {
    await pumpSplash(tester, screen: const Size(480, 1000));
    expect(tester.takeException(), isNull);
  });
}
