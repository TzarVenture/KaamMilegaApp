import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/shared/widgets/app_button.dart';
import 'package:kaam_milega/shared/widgets/app_text_field.dart';

/// Batch 2 (buttons + text fields): visual polish must not change behaviour.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  group('AppButton', () {
    testWidgets('tap calls onPressed once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(text: 'Verify & Continue', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('while loading: spinner shown and taps ignored', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppButton(
            text: 'Verify & Continue',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
    });

    testWidgets('disabled button (no onPressed) does nothing', (tester) async {
      await tester.pumpWidget(host(const AppButton(text: 'Continue')));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('long text on a small screen does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          AppButton(
            text: 'A very long button label that will not fit on one line',
            icon: Icons.check,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('AppTextField', () {
    testWidgets('typing reaches the controller and error text shows', (
      tester,
    ) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: AppTextField(
              controller: controller,
              hintText: 'Email',
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please enter your email address to continue'
                  : null,
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(
        find.text('Please enter your email address to continue'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      expect(controller.text, 'user@example.com');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
