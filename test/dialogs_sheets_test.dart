import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/shared/widgets/app_dialog.dart';
import 'package:kaam_milega/shared/widgets/auth_prompt_dialog.dart';
import 'package:kaam_milega/shared/widgets/sheet_drag_handle.dart';

/// Batch 3 (dialogs + sheets): new look, same actions.
void main() {
  group('showAppDialog', () {
    testWidgets('returns the popped value like showDialog', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAppDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'yes'),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(result, 'yes');
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('tapping outside closes it (barrierDismissible)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('Info')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsNothing);
    });
  });

  group('Login Required popup', () {
    Future<void> pumpApp(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAuthPromptDialog(
                    context,
                    title: 'Login Required',
                    message: 'Please login to access your wallet.',
                  ),
                  child: const Text('Wallet'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('LOGIN SCREEN')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
    }

    testWidgets('Cancel just closes the popup', (tester) async {
      await pumpApp(tester);
      expect(find.text('Please login to access your wallet.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Login Required'), findsNothing);
      expect(find.text('LOGIN SCREEN'), findsNothing);
    });

    testWidgets('Login still opens the Login screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN SCREEN'), findsOneWidget);
    });

    testWidgets('long text on a small phone does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpApp(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('SheetDragHandle renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SheetDragHandle())),
    );
    expect(find.byType(SheetDragHandle), findsOneWidget);
  });
}
