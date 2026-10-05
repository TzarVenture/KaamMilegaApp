import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/events/models/event.dart';
import 'package:kaam_milega/features/events/presentation/events_screen.dart';
import 'package:kaam_milega/features/events/providers/event_provider.dart';
import 'package:kaam_milega/shared/widgets/banner_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoEvents extends EventsNotifier {
  @override
  Future<List<EventItem>> build() async => [];
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

/// Banner size on a screen [width] wide.
Future<Size> _bannerSize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_Guest.new),
        eventsProvider.overrideWith(_NoEvents.new),
      ],
      child: const MaterialApp(home: EventsScreen()),
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  const ratio = 1080 / 754;

  for (final width in [320.0, 360.0, 430.0, 600.0]) {
    testWidgets('fills the width and keeps its shape at $width px', (
      tester,
    ) async {
      final size = await _bannerSize(tester, width);
      expect(tester.takeException(), isNull);
      // Full width inside the list's 16px side padding
      expect(size.width, closeTo(width - 32, 0.5));
      expect(size.width / size.height, closeTo(ratio, 0.01));
    });
  }

  testWidgets('wide tablet: at most 720 wide, same shape', (tester) async {
    final size = await _bannerSize(tester, 1000);
    expect(size.width, closeTo(720, 0.5));
    expect(size.width / size.height, closeTo(ratio, 0.01));
  });

  testWidgets('bigger screen, bigger banner', (tester) async {
    final small = await _bannerSize(tester, 360);
    final large = await _bannerSize(tester, 600);
    expect(large.height, greaterThan(small.height));
  });
}
