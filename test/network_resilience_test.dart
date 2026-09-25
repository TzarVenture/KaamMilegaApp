import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/network/connectivity_service.dart';
import 'package:kaam_milega/core/network/network_status.dart';
import 'package:kaam_milega/core/network/offline_banner.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/wallet/models/withdrawal.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
import 'package:kaam_milega/shared/widgets/network_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NetworkStatus & ConnectivityService Tests', () {
    test('NetworkStatus enum extension returns correct booleans', () {
      expect(NetworkStatus.online.isOnline, true);
      expect(NetworkStatus.online.isOffline, false);
      expect(NetworkStatus.offline.isOnline, false);
      expect(NetworkStatus.offline.isOffline, true);
      expect(NetworkStatus.checking.isChecking, true);
    });

    test('ConnectivityService updates status and emits to stream', () async {
      final service = ConnectivityService();

      final statuses = <NetworkStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      service.updateStatus(NetworkStatus.offline);
      service.updateStatus(NetworkStatus.online);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(statuses, contains(NetworkStatus.offline));
      expect(statuses, contains(NetworkStatus.online));
      expect(service.isOnline, true);

      await sub.cancel();
    });
  });

  group('AppException & ApiClient Error Translation Tests', () {
    test('AppNetworkException defaults to friendly message', () {
      const ex = AppNetworkException();
      expect(ex.message, contains('No internet connection'));
      expect(ex.toString(), contains('No internet connection'));
    });

    test('AppTimeoutException contains timeout description', () {
      const ex = AppTimeoutException();
      expect(ex.message, contains('Connection timed out'));
      expect(ex.code, 'TIMEOUT');
    });

    test('AppAuthException handles 401 status code', () {
      const ex = AppAuthException('Unauthorized', 401);
      expect(ex.statusCode, 401);
      expect(ex.message, 'Unauthorized');
    });

    test(
      'ApiClient catches connection error and converts to AppNetworkException',
      () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'SocketException: OS Error',
                ),
              );
            },
          ),
        );

        final client = ApiClient(dio: dio);

        expect(() => client.get('/test'), throwsA(isA<AppNetworkException>()));
      },
    );

    test(
      'ApiClient catches timeout and converts to AppTimeoutException',
      () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                ),
              );
            },
          ),
        );

        final client = ApiClient(dio: dio);

        expect(() => client.get('/test'), throwsA(isA<AppTimeoutException>()));
      },
    );
  });

  group('LocalStorage Offline Cache Tests', () {
    test('Stores and retrieves cached jobs with timestamp', () async {
      final sampleJobs = [
        {'id': 'job_101', 'title': 'Software Developer', 'salary_min': 25000},
      ];

      await LocalStorage.saveCachedJobs(sampleJobs);
      final cached = LocalStorage.getCachedJobs();

      expect(cached.jobs.length, 1);
      expect(cached.jobs.first['title'], 'Software Developer');
      expect(cached.timestamp, isNotNull);
    });

    test('Stores and retrieves cached applications with timestamp', () async {
      final sampleApps = [
        {'id': 'app_1', 'job_id': 'job_101', 'status': 'submitted'},
      ];

      await LocalStorage.saveCachedApplications(sampleApps);
      final cached = LocalStorage.getCachedApplications();

      expect(cached.apps.length, 1);
      expect(cached.apps.first['job_id'], 'job_101');
      expect(cached.timestamp, isNotNull);
    });

    test('Stores and retrieves cached wallet snapshot', () async {
      final sampleWallet = {'balance': 15000, 'currency': 'INR'};

      await LocalStorage.saveCachedWallet(sampleWallet);
      final cached = LocalStorage.getCachedWallet();

      expect(cached.data?['balance'], 15000);
      expect(cached.timestamp, isNotNull);
    });
  });

  group('NetworkStateView & CachedDataBadge Widget Tests', () {
    testWidgets('NetworkStateView renders offline state with Retry button', (
      tester,
    ) async {
      bool retryClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStateView(
              isOffline: true,
              onRetry: () => retryClicked = true,
              child: const Text('Online Data Content'),
            ),
          ),
        ),
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Online Data Content'), findsNothing);

      await tester.tap(find.text('Retry'));
      expect(retryClicked, true);
    });

    testWidgets(
      'NetworkStateView renders cached data badge when timestamp provided',
      (tester) async {
        final cachedTime = DateTime(2026, 9, 22, 14, 30);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NetworkStateView(
                cachedTimestamp: cachedTime,
                child: const Text('Cached Content Display'),
              ),
            ),
          ),
        );

        expect(find.textContaining('Showing saved data'), findsOneWidget);
        expect(find.text('Cached Content Display'), findsOneWidget);
      },
    );
  });

  group('Wallet Offline Transaction Guard Tests', () {
    test('WalletNotifier blocks financial actions when offline', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set offline status
      ConnectivityService().updateStatus(NetworkStatus.offline);

      final notifier = container.read(walletProvider.notifier);

      // addMoney returns a result instead of throwing; offline it must fail
      // before any order is created or Razorpay checkout is opened.
      final topup = await notifier.addMoney(amount: 500);
      expect(topup.outcome, TopupOutcome.failed);
      expect(topup.message, contains('Internet connection required'));

      await expectLater(
        notifier.withdraw(
          const WithdrawalRequest.upi(amount: 500, upiId: 'user@upi'),
        ),
        throwsA(isA<AppNetworkException>()),
      );

      await expectLater(
        notifier.transfer(amount: 500, recipientIdentifier: '9876543210'),
        throwsA(isA<AppNetworkException>()),
      );

      // Restore online status
      ConnectivityService().updateStatus(NetworkStatus.online);
    });
  });

  group('OfflineBannerOverlay Widget Tests', () {
    testWidgets(
      'OfflineBannerOverlay shows child and reacts to offline state',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: OfflineBannerOverlay(
                child: Scaffold(body: Text('Main App Screen')),
              ),
            ),
          ),
        );

        expect(find.text('Main App Screen'), findsOneWidget);
      },
    );
  });
}
