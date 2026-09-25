import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/repositories/auth_repository.dart';
import 'package:kaam_milega/features/profile/presentation/widgets/open_to_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ApiClient answered locally; records every request.
({ApiClient client, List<RequestOptions> sent}) _fake(
  Response<dynamic> Function(RequestOptions o) respond,
) {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        handler.resolve(respond(options));
      },
    ),
  );
  return (client: ApiClient(dio: dio), sent: sent);
}

Response<dynamic> _ok(RequestOptions o, dynamic data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

Map<String, dynamic> _user({
  Map<String, dynamic>? openToWork,
  Map<String, dynamic>? providingServices,
}) => {
  'id': 'u1',
  'mobile': '9876543210',
  'is_registered': true,
  'open_to_work': ?openToWork,
  'providing_services': ?providingServices,
};

/// Records the preferences the sheets send (no network).
class _PrefsRepo extends AuthRepository {
  _PrefsRepo({this.fail = false}) : super(ApiClient());
  final bool fail;
  final List<OpenToWorkPreferences> work = [];
  final List<ProvidingServicesPreferences> services = [];

  @override
  Future<UserProfile> updateOpenToWork(OpenToWorkPreferences prefs) async {
    work.add(prefs);
    if (fail) throw const AppServerException();
    return UserProfile.fromJson(_user(openToWork: prefs.toJson()));
  }

  @override
  Future<UserProfile> updateProvidingServices(
    ProvidingServicesPreferences prefs,
  ) async {
    services.add(prefs);
    if (fail) throw const AppServerException();
    return UserProfile.fromJson(_user(providingServices: prefs.toJson()));
  }
}

/// A page with a button that opens [open] and shows the sheet's result.
Widget _host(
  _PrefsRepo repo,
  Future<String?> Function(BuildContext context) open,
) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: _Host(open: open),
    ),
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.open});
  final Future<String?> Function(BuildContext context) open;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String result = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('result: $result'),
          ElevatedButton(
            onPressed: () async {
              final r = await widget.open(context);
              setState(() => result = r ?? 'closed');
            },
            child: const Text('Open sheet'),
          ),
        ],
      ),
    );
  }
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}

/// Taps [finder] after closing the keyboard and scrolling it into view.
/// (A focused text field scrolls itself back into view, which can move
/// the target off screen again.)
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Requests match the backend contract', () {
    test('PATCH /user/open-to-work sends the whole object', () async {
      final f = _fake(
        (o) => _ok(o, {
          'message': 'Open to work preferences updated',
          'open_to_work': o.data,
          'user': _user(openToWork: o.data as Map<String, dynamic>),
        }),
      );
      final user = await AuthRepository(f.client).updateOpenToWork(
        const OpenToWorkPreferences(
          isOpen: true,
          jobTitles: ['Electrician'],
          jobTypes: ['Part-time'],
          locations: ['Pune'],
          visibility: 'recruiters',
        ),
      );
      final req = f.sent.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/user/open-to-work');
      expect(req.data, {
        'is_open': true,
        'job_titles': ['Electrician'],
        'job_types': ['Part-time'],
        'locations': ['Pune'],
        'visibility': 'recruiters',
      });
      expect(user.isOpenToWork, isTrue);
      expect(user.openToWorkPreferences?.visibility, 'recruiters');
    });

    test('PATCH /user/providing-services sends rate and currency', () async {
      final f = _fake(
        (o) => _ok(o, {
          'user': _user(providingServices: o.data as Map<String, dynamic>),
        }),
      );
      await AuthRepository(f.client).updateProvidingServices(
        const ProvidingServicesPreferences(
          isProviding: true,
          services: ['AC Repair'],
          hourlyRate: 450.5,
          currency: 'INR',
          description: 'Split and window ACs',
        ),
      );
      expect(f.sent.single.method, 'PATCH');
      expect(f.sent.single.path, '/user/providing-services');
      expect(f.sent.single.data, {
        'is_providing': true,
        'services': ['AC Repair'],
        'hourly_rate': 450.5,
        'currency': 'INR',
        'description': 'Split and window ACs',
      });
    });

    test('a response without the profile is an error', () async {
      final f = _fake((o) => _ok(o, {'message': 'ok'}));
      await expectLater(
        AuthRepository(f.client)
            .updateOpenToWork(const OpenToWorkPreferences(isOpen: true)),
        throwsA(isA<AppValidationException>()),
      );
    });

    test('options come from the website form and backend defaults', () {
      expect(OpenToWorkPreferences.jobTypeOptions, [
        'Full-time',
        'Part-time',
        'Contract',
        'Freelance',
        'Hourly',
      ]);
      expect(OpenToWorkPreferences.visibilityAll, 'all');
      expect(OpenToWorkPreferences.visibilityRecruiters, 'recruiters');
      expect(ProvidingServicesPreferences.defaultCurrency, 'INR');
    });

    test('chip values are trimmed and not duplicated', () {
      final values = <String>['Driver'];
      final ctrl = TextEditingController(text: '  driver ');
      expect(addChipValue(values, ctrl), isFalse);
      ctrl.text = ' Plumber ';
      expect(addChipValue(values, ctrl), isTrue);
      expect(values, ['Driver', 'Plumber']);
      expect(ctrl.text, isEmpty);
    });
  });

  group('Open To Work sheet', () {
    const user = UserProfile(id: 'u1', mobile: '9876543210');

    testWidgets('saves titles, job types, locations and visibility', (
      tester,
    ) async {
      final repo = _PrefsRepo();
      await tester.pumpWidget(_host(repo, (c) => showOpenToWorkSheet(c, user)));
      await _openSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Electrician');
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Part-time'));
      // Typed but not added: still saved.
      await tester.enterText(find.byType(TextField).at(1), 'Pune');
      await _tapVisible(tester, find.text('Recruiters only'));
      await _tapVisible(tester, find.text('Save'));

      final sent = repo.work.single;
      expect(sent.isOpen, isTrue);
      expect(sent.jobTitles, ['Electrician']);
      expect(sent.jobTypes, ['Part-time']);
      expect(sent.locations, ['Pune']);
      expect(sent.visibility, 'recruiters');
      expect(find.text('result: Open To Work saved.'), findsOneWidget);
    });

    testWidgets('no job title: not sent, message shown', (tester) async {
      final repo = _PrefsRepo();
      await tester.pumpWidget(_host(repo, (c) => showOpenToWorkSheet(c, user)));
      await _openSheet(tester);
      await _tapVisible(tester, find.text('Save'));
      expect(repo.work, isEmpty);
      expect(find.text('Add at least one job title.'), findsOneWidget);
    });

    testWidgets('server error: sheet stays open with the error', (
      tester,
    ) async {
      final repo = _PrefsRepo(fail: true);
      await tester.pumpWidget(_host(repo, (c) => showOpenToWorkSheet(c, user)));
      await _openSheet(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Driver');
      await _tapVisible(tester, find.text('Save'));
      expect(repo.work, hasLength(1));
      expect(
        find.text(
          'Server is temporarily unavailable. Please try again shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('result: none'), findsOneWidget);
    });

    testWidgets('turn off keeps the saved values and unknown job types', (
      tester,
    ) async {
      final repo = _PrefsRepo();
      final saved = UserProfile.fromJson(
        _user(
          openToWork: {
            'is_open': true,
            'job_titles': ['Driver'],
            'job_types': ['Internship'],
            'locations': ['Delhi'],
            'visibility': 'all',
          },
        ),
      );
      await tester.pumpWidget(
        _host(repo, (c) => showOpenToWorkSheet(c, saved)),
      );
      await _openSheet(tester);
      // Saved value outside the website list is shown, not dropped.
      expect(find.widgetWithText(FilterChip, 'Internship'), findsOneWidget);
      await _tapVisible(tester, find.text('Turn off Open To Work'));
      final sent = repo.work.single;
      expect(sent.isOpen, isFalse);
      expect(sent.jobTitles, ['Driver']);
      expect(sent.jobTypes, ['Internship']);
      expect(sent.locations, ['Delhi']);
      expect(sent.visibility, 'all');
    });

    testWidgets('old phone-only text is shown, not converted', (tester) async {
      final repo = _PrefsRepo();
      const legacy = UserProfile(
        id: 'u1',
        mobile: '9876543210',
        openToWork: 'Driver, Cook',
      );
      await tester.pumpWidget(
        _host(repo, (c) => showOpenToWorkSheet(c, legacy)),
      );
      await _openSheet(tester);
      expect(find.textContaining('"Driver, Cook"'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('fits a small phone screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(_PrefsRepo(), (c) => showOpenToWorkSheet(c, user)),
      );
      await _openSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Open To Work'), findsOneWidget);
    });
  });

  group('Providing Services sheet', () {
    testWidgets('saves services, rate, INR and description', (tester) async {
      final repo = _PrefsRepo();
      const user = UserProfile(id: 'u1', mobile: '9876543210');
      await tester.pumpWidget(
        _host(repo, (c) => showProvidingServicesSheet(c, user)),
      );
      await _openSheet(tester);
      await tester.enterText(find.byType(TextField).at(0), 'AC Repair');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '500');
      await tester.enterText(
        find.byType(TextField).at(2),
        '  Split and window ACs  ',
      );
      await _tapVisible(tester, find.text('Save'));

      final sent = repo.services.single;
      expect(sent.isProviding, isTrue);
      expect(sent.services, ['AC Repair']);
      expect(sent.hourlyRate, 500);
      expect(sent.currency, 'INR');
      expect(sent.description, 'Split and window ACs');
      expect(find.text('result: Providing Services saved.'), findsOneWidget);
    });

    testWidgets('prefills saved values; turn off keeps them', (tester) async {
      final repo = _PrefsRepo();
      final saved = UserProfile.fromJson(
        _user(
          providingServices: {
            'is_providing': true,
            'services': ['Plumbing'],
            'hourly_rate': 300,
            'currency': 'INR',
            'description': 'Home repairs',
          },
        ),
      );
      await tester.pumpWidget(
        _host(repo, (c) => showProvidingServicesSheet(c, saved)),
      );
      await _openSheet(tester);
      expect(find.widgetWithText(InputChip, 'Plumbing'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('Home repairs'), findsOneWidget);

      await _tapVisible(tester, find.text('Turn off Providing Services'));
      final sent = repo.services.single;
      expect(sent.isProviding, isFalse);
      expect(sent.services, ['Plumbing']);
      expect(sent.hourlyRate, 300);
      expect(sent.description, 'Home repairs');
    });

    testWidgets('no service: not sent, message shown', (tester) async {
      final repo = _PrefsRepo();
      const user = UserProfile(id: 'u1', mobile: '9876543210');
      await tester.pumpWidget(
        _host(repo, (c) => showProvidingServicesSheet(c, user)),
      );
      await _openSheet(tester);
      await _tapVisible(tester, find.text('Save'));
      expect(repo.services, isEmpty);
      expect(find.text('Add at least one service.'), findsOneWidget);
    });
  });
}
