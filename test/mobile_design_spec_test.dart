import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_colors.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/app/theme/app_theme_mobile.dart';
import 'package:kaam_milega/app/theme/mobile_design_spec.dart';
import 'package:kaam_milega/shared/widgets/app_bottom_nav.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('Mobile Design Specification trial', () {
    test('the app runs with the theme the switch selects', () {
      expect(
        identical(
          AppTheme.appTheme,
          kMobileDesignSpec ? AppMobileTheme.theme : AppTheme.lightTheme,
        ),
        isTrue,
      );
    });

    test('text colours meet WCAG AA (4.5 : 1) on their backgrounds', () {
      if (!kMobileDesignSpec) return; // old colours are unchanged
      const white = AppColors.white;
      final pairs = <String, double>{
        'navy label on orange button': _contrast(
          AppColors.onAccent,
          AppColors.accent,
        ),
        'orange text on white': _contrast(AppColors.accentOnLight, white),
        'secondary text on canvas': _contrast(
          AppColors.textSecondary,
          AppColors.background,
        ),
        'hint text on white': _contrast(AppColors.textLight, white),
        'error text on white': _contrast(AppColors.error, white),
        'InstantMilega text': _contrast(AppColors.moduleInstantWorkText, white),
        'Skills text': _contrast(AppColors.moduleSkillsText, white),
        'Services text': _contrast(AppColors.moduleServicesText, white),
        'Peer-to-Peer text': _contrast(AppColors.moduleP2PText, white),
        'Events text': _contrast(AppColors.moduleEventsText, white),
        'link blue on white': _contrast(AppColors.blue, white),
      };
      for (final e in pairs.entries) {
        expect(e.value, greaterThanOrEqualTo(4.5), reason: e.key);
      }
      // The pairing the spec forbids really fails.
      expect(_contrast(white, AppColors.accent), lessThan(3));
    });

    test('components follow the spec', () {
      if (!kMobileDesignSpec) return;
      final t = AppMobileTheme.theme;
      final button = t.elevatedButtonTheme.style!;
      expect(button.minimumSize!.resolve({})!.height, 48);
      expect(button.textStyle!.resolve({})!.fontSize, 16);
      expect(
        button.backgroundColor!.resolve({WidgetState.disabled}),
        AppColors.border,
      );
      final focus = t.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      expect(focus.borderSide.color, AppColors.blue);
      expect(focus.borderSide.width, 2);
      expect(t.inputDecorationTheme.hintStyle!.fontSize, 16);
      expect(t.chipTheme.shape, isA<StadiumBorder>());
      final card = t.cardTheme.shape as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(14));
      final sheet = t.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(
        sheet.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(20)),
      );
      expect(t.textTheme.bodySmall!.fontSize, 13); // nothing readable < 13
      expect(t.textTheme.labelSmall!.fontSize, 11); // tab labels only
    });

    testWidgets('bottom bar fits a 320px phone at 130% text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var tapped = '';
      Widget item(String label, {bool selected = false}) => AppBottomNavItem(
        icon: Icons.home_outlined,
        label: label,
        selected: selected,
        onTap: () => tapped = label,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.appTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              bottomNavigationBar: AppBottomNav.frame(
                children: [
                  item('Home', selected: true),
                  item('Jobs'),
                  AppNavCenterButton(onTap: () {}, legacy: const SizedBox()),
                  item('Chats'),
                  item('Profile'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Profile'));
      expect(tapped, 'Profile');
      if (kMobileDesignSpec) {
        // Every tab is at least 48px tall to tap.
        expect(
          tester.getSize(find.byType(AppBottomNavItem).first).height,
          greaterThanOrEqualTo(48),
        );
      }
    });

    testWidgets('orange bar slides smoothly to the tapped tab', (tester) async {
      if (!kMobileDesignSpec) return;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var active = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.appTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              Widget item(int i, String label) => AppBottomNavItem(
                icon: Icons.home_outlined,
                label: label,
                selected: active == i,
                indicatorInBar: true,
                onTap: () => setState(() => active = i),
              );
              return Scaffold(
                bottomNavigationBar: AppBottomNav.frame(
                  activeIndex: active,
                  children: [
                    item(0, 'Home'),
                    item(1, 'Jobs'),
                    AppNavCenterButton(onTap: () {}, legacy: const SizedBox()),
                    item(3, 'Chats'),
                    item(4, 'Profile'),
                  ],
                ),
              );
            },
          ),
        ),
      );
      double barX() =>
          tester.getTopLeft(find.byKey(AppBottomNav.indicatorKey)).dx;
      // The bar may first glide from the tab of the previous bar.
      await tester.pumpAndSettle();
      // 5 equal slots of 80px: the 24px bar is centred in slot 0.
      expect(barX(), 28);

      await tester.tap(find.text('Chats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Part of the way there: moving, not jumping.
      expect(barX(), greaterThan(28));
      expect(barX(), lessThan(3 * 80 + 28));

      await tester.pumpAndSettle();
      expect(barX(), 3 * 80 + 28);
      expect(tester.takeException(), isNull);
    });
  });
}
