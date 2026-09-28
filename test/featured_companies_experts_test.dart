import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/company/models/top_company.dart';
import 'package:kaam_milega/features/company/providers/company_provider.dart';
import 'package:kaam_milega/features/company/repositories/company_repository.dart';
import 'package:kaam_milega/features/home/presentation/widgets/connect_like_you_section.dart';
import 'package:kaam_milega/features/home/presentation/widgets/featured_companies_section.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:kaam_milega/features/network/repositories/network_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request locally (no network); records each request.
({ApiClient client, List<RequestOptions> sent}) _fakeClient(
  Response<dynamic> Function(RequestOptions options) respond,
) {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        try {
          handler.resolve(respond(options));
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return (client: ApiClient(dio: dio), sent: sent);
}

Response<dynamic> _ok(RequestOptions o, dynamic data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Featured companies (GET /companies/top)', () {
    test('backend placeholders are not shown as company facts', () {
      final c = TopCompany.fromJson({
        'id': 'r1',
        'name': 'Acme Logistics',
        'category': 'Enterprise Employer',
        'location': 'India',
        'job_count': 1,
        'verified': false,
      });
      expect(c.category, isEmpty);
      expect(c.location, isEmpty);
      expect(c.verified, isFalse);
      expect(c.initials, 'AL');

      final real = TopCompany.fromJson({
        'id': 'r2',
        'name': 'Metro Movers',
        'category': 'Logistics',
        'location': 'Pune',
        'verified': true,
      });
      expect(real.category, 'Logistics');
      expect(real.location, 'Pune');
      expect(real.verified, isTrue);
    });

    test('list: {data: [...]}, entries without id or name skipped', () async {
      final f = _fakeClient(
        (o) => _ok(o, {
          'data': [
            {'id': 'r1', 'name': 'Acme Logistics'},
            {'id': '', 'name': 'No Id'},
            {'id': 'r3', 'name': ''},
          ],
        }),
      );
      final list = await CompanyRepository(f.client).getTopCompanies();
      expect(list.map((c) => c.name), ['Acme Logistics']);
      expect(f.sent.single.path, '/companies/top');
      expect(f.sent.single.queryParameters['limit'], 10);
    });

    test('company jobs: GET /jobs?recruiter_id=, open jobs only', () async {
      final f = _fakeClient(
        (o) => _ok(o, [
          {'id': 'j1', 'title': 'Driver', 'status': 'Open'},
          {'id': 'j2', 'title': 'Packer', 'status': 'Closed'},
          {'id': 'j3', 'title': 'Helper', 'status': 'On Hold'},
          {'id': 'j4', 'title': 'Loader'},
        ]),
      );
      final jobs = await CompanyRepository(f.client).getOpenJobs('r1');
      expect(jobs.map((j) => j.id), ['j1', 'j4']);
      expect(f.sent.single.path, '/jobs');
      expect(f.sent.single.queryParameters, {'recruiter_id': 'r1'});
    });

    testWidgets('cards: "Verified Employer" only when the server says so', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topCompaniesProvider.overrideWith(
              (ref) async => const [
                TopCompany(id: 'r1', name: 'Acme Logistics', verified: true),
                TopCompany(id: 'r2', name: 'Metro Movers', location: 'Pune'),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FeaturedCompaniesSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acme Logistics'), findsOneWidget);
      expect(find.text('Metro Movers'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('Verified Employer'), findsOneWidget);
      expect(find.text('View Jobs →'), findsNWidgets(2));
      // No invented counts
      expect(find.textContaining('5,000+'), findsNothing);
    });

    testWidgets('no employers: section hidden', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topCompaniesProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FeaturedCompaniesSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Actively Hiring'), findsNothing);
    });
  });

  group('Connect With Our Experts (GET /experts)', () {
    test('experts list request', () async {
      final f = _fakeClient(
        (o) => _ok(o, [
          {'id': 'e1', 'name': 'Anwar', 'headline': 'Delivery Specialist'},
        ]),
      );
      final experts = await NetworkRepository(f.client).getExperts();
      expect(experts.single.name, 'Anwar');
      expect(f.sent.single.path, '/experts');
    });

    testWidgets('shows expert cards with Connect and Chat', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Guest.new),
            featuredExpertsProvider.overrideWith(
              (ref) async => const [
                UserProfile(
                  id: 'e1',
                  mobile: '9111111111',
                  name: 'Anwar',
                  headline: 'Delivery Specialist',
                  city: 'Mumbai',
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ConnectExpertsSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anwar'), findsOneWidget);
      expect(find.text('Delivery Specialist'), findsOneWidget);
      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Connect'), findsOneWidget);
      expect(find.textContaining('9111111111'), findsNothing);
    });
  });
}
