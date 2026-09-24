import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/shared/widgets/fade_slide_in.dart';
import 'package:kaam_milega/shared/widgets/network_state_view.dart';
import 'package:kaam_milega/shared/widgets/pressable_scale.dart';

/// Batch 4 (cards, lists, states): visual only, same behaviour.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  group('FadeSlideIn', () {
    testWidgets('shows the child after the entrance', (tester) async {
      await tester.pumpWidget(
        host(const FadeSlideIn(index: 2, child: Text('Item'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Item'), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('items after the first few are not animated', (tester) async {
      await tester.pumpWidget(
        host(const FadeSlideIn(index: 20, child: Text('Late item'))),
      );
      expect(find.text('Late item'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('long list scrolls without errors', (tester) async {
      await tester.pumpWidget(
        host(
          ListView.builder(
            itemCount: 100,
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: SizedBox(height: 60, child: Text('Row $index')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('PressableScale does not block taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        PressableScale(
          child: InkWell(
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 80, child: Text('Card')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  group('NetworkStateView states', () {
    testWidgets('error state keeps the message and Retry works', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        host(
          NetworkStateView(
            errorMessage: 'Server temporarily unavailable.',
            onRetry: () => retried = true,
            child: const Text('Data'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Unable to Load Data'), findsOneWidget);
      expect(find.text('Server temporarily unavailable.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('empty state fits a small phone with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: NetworkStateView(
                isEmpty: true,
                emptyTitle: 'No Applications Yet',
                emptyMessage:
                    'Jobs you apply for will appear here so you can track '
                    'their status.',
                emptyAction: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Browse Jobs'),
                ),
                child: const Text('Data'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('No Applications Yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('content state shows the child', (tester) async {
      await tester.pumpWidget(
        host(const NetworkStateView(child: Text('Loaded content'))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Loaded content'), findsOneWidget);
    });
  });
}
