import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/payments/razorpay_checkout.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/events/models/event.dart';
import 'package:kaam_milega/features/events/models/event_ticket.dart';
import 'package:kaam_milega/features/events/presentation/event_detail_screen.dart';
import 'package:kaam_milega/features/events/presentation/widgets/event_ticket_view.dart';
import 'package:kaam_milega/features/events/providers/event_provider.dart';
import 'package:kaam_milega/features/events/providers/event_ticket_provider.dart';
import 'package:kaam_milega/features/events/repositories/event_repository.dart';
import 'package:kaam_milega/features/wallet/models/wallet_dispute.dart';
import 'package:kaam_milega/features/wallet/models/wallet_transaction.dart';
import 'package:kaam_milega/features/wallet/presentation/wallet_disputes_screen.dart';
import 'package:kaam_milega/features/wallet/presentation/widgets/refund_request_sheet.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
import 'package:kaam_milega/features/wallet/repositories/wallet_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Answers every request locally (no network, no real payment): records the
/// request and returns [respond]'s response, or throws its DioException.
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

DioException _httpError(RequestOptions o, int status, String message) =>
    DioException(
      requestOptions: o,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: status,
        data: <String, dynamic>{'error': message},
      ),
    );

const _eventJson = <String, dynamic>{
  'id': 'e1',
  'title': 'Hiring Expo',
  'organizer': 'KaamMilega',
  'date': '2026-10-12',
  'time': '5:00 PM',
  'location': 'Pune',
  'is_paid': true,
  'price': 499,
  'currency': 'INR',
  'capacity': 50,
  'available_seats': 12,
  'participants': <String>[],
};

Map<String, dynamic> _ticketJson({String method = 'razorpay'}) => {
  'id': 't1',
  'ticket_number': 'TKT-EVT-123456',
  'event_id': 'e1',
  'user_id': 'u1',
  'attendee_name': 'Test User',
  'attendee_email': 'test@example.com',
  'amount': 499,
  'payment_status': 'paid',
  'payment_method': method,
  'razorpay_payment_id': method == 'razorpay' ? 'pay_1' : '',
  'status': 'confirmed',
  'qr_code_data': 'KM:EVENT:e1:u1:TKT-EVT-123456',
  'event_title': 'Hiring Expo',
  'event_date': '2026-10-12',
  'event_time': '5:00 PM',
  'event_location': 'Pune',
  'created_at': '2026-09-28T10:00:00Z',
};

const _attendee = EventAttendee(name: ' Test User ', email: 'test@example.com');

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9876543210'),
  );
}

/// Wallet that never calls the server; counts reloads.
class _Wallet extends WalletNotifier {
  int loads = 0;

  @override
  WalletState build() => const WalletState();

  @override
  Future<void> loadWallet() async => loads++;
}

/// Stands in for the Razorpay screen; records the orders it was opened for.
TicketPaymentLauncher _launcher(RazorpayResult result, List<String> opened) =>
    ({
      required String keyId,
      required String orderId,
      required int amountPaise,
      required String description,
      String? email,
      String? contact,
    }) async {
      opened.add('$orderId:$amountPaise');
      return result;
    };

final _paid = RazorpayResult.paid(
  paymentId: 'pay_1',
  orderId: 'order_1',
  signature: 'sig_1',
);

ProviderContainer _container(ApiClient client, TicketPaymentLauncher pay) {
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      walletProvider.overrideWith(_Wallet.new),
      eventRepositoryProvider.overrideWithValue(EventRepository(client)),
      ticketPaymentLauncherProvider.overrideWithValue(pay),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Routes the ticket endpoints like the backend (F63).
Response<dynamic> Function(RequestOptions) _backend({
  DioException Function(RequestOptions o)? verifyError,
  DioException Function(RequestOptions o)? walletError,
  DioException Function(RequestOptions o)? orderError,
}) {
  return (o) {
    switch (o.path) {
      case '/events':
        return _ok(o, {
          'data': [_eventJson],
        });
      case '/events/e1/create-order':
        if (orderError != null) throw orderError(o);
        return _ok(o, {
          'order_id': 'order_1',
          'amount': 499,
          'amount_paise': 49900,
          'currency': 'INR',
          'key_id': 'rzp_test_key',
          'event_title': 'Hiring Expo',
        });
      case '/events/e1/verify-payment':
        if (verifyError != null) throw verifyError(o);
        return _ok(o, {'message': 'ok', 'ticket': _ticketJson()});
      case '/events/e1/wallet-checkout':
        if (walletError != null) throw walletError(o);
        return _ok(o, {
          'message': 'ok',
          'ticket': _ticketJson(method: 'wallet'),
          'wallet': {'main_balance': 501, 'total_balance': 501},
        });
    }
    throw _httpError(o, 404, 'not found');
  };
}

WalletTransaction _txn({
  String type = 'debit',
  String category = 'event_ticket',
}) => WalletTransaction.fromJson({
  'id': 'tx1',
  'amount': 499,
  'type': type,
  'status': 'completed',
  'category': category,
  'created_at': '2026-09-28T10:00:00Z',
});

void main() {
  group('Event model (paid tickets)', () {
    test('reads price, seats and payment rule from the backend', () {
      final event = EventItem.fromJson(_eventJson);
      expect(event.requiresPayment, isTrue);
      expect(event.priceLabel, '₹499');
      expect(event.seatsLeft, 12);
      expect(event.isSoldOut, isFalse);
    });

    test('capacity with available_seats omitted (0) is sold out', () {
      final event = EventItem.fromJson({
        ..._eventJson,
        'available_seats': null,
      });
      expect(event.isSoldOut, isTrue);
      expect(event.seatsLeft, 0);
    });

    test('free event and paise prices', () {
      final free = EventItem.fromJson({'id': 'f1', 'title': 'Webinar'});
      expect(free.requiresPayment, isFalse);
      expect(free.priceLabel, 'Free');
      expect(free.seatsLeft, isNull);
      expect(free.isSoldOut, isFalse);

      final paise = EventItem.fromJson({..._eventJson, 'price': 99.5});
      expect(paise.priceLabel, '₹99.50');

      // is_paid without a price is still free, as on the backend
      final zero = EventItem.fromJson({..._eventJson, 'price': 0});
      expect(zero.requiresPayment, isFalse);
    });

    test('ticket parses and labels its payment', () {
      final ticket = EventTicket.fromJson(_ticketJson(method: 'wallet'));
      expect(ticket.ticketNumber, 'TKT-EVT-123456');
      expect(ticket.paymentLabel, '₹499 · Wallet');
      expect(ticket.statusLabel, 'Confirmed');
      expect(ticket.whenLabel, '2026-10-12 · 5:00 PM');
      expect(
        EventTicket.fromJson({..._ticketJson(), 'payment_status': 'refunded'})
            .statusLabel,
        'Refunded',
      );
    });

    test('attendee body trims and leaves out an empty phone', () {
      expect(_attendee.toJson(), {
        'attendee_name': 'Test User',
        'attendee_email': 'test@example.com',
      });
    });
  });

  group('Ticket checkout (no real payment)', () {
    test('online: order, checkout, then server verification', () async {
      final f = _fakeClient(_backend());
      final opened = <String>[];
      final c = _container(f.client, _launcher(_paid, opened));
      final event = (await c.read(eventsProvider.future)).single;

      final result = await c
          .read(eventTicketCheckoutProvider)
          .payOnline(event, _attendee);

      expect(result.outcome, TicketPurchaseOutcome.success);
      expect(result.ticket?.ticketNumber, 'TKT-EVT-123456');
      expect(opened, ['order_1:49900']);
      final paths = f.sent.map((o) => o.path).toList();
      expect(paths, [
        '/events',
        '/events/e1/create-order',
        '/events/e1/verify-payment',
      ]);
      expect(f.sent[2].data, {
        'razorpay_order_id': 'order_1',
        'razorpay_payment_id': 'pay_1',
        'razorpay_signature': 'sig_1',
        'attendee_name': 'Test User',
        'attendee_email': 'test@example.com',
      });
      // Shown as registered only after the server issued the ticket
      expect(c.read(eventsProvider).value!.single.isRegistered, isTrue);
      expect(c.read(eventsProvider).value!.single.seatsLeft, 11);
    });

    test('cancelled checkout never asks the server to verify', () async {
      final f = _fakeClient(_backend());
      final c = _container(
        f.client,
        _launcher(RazorpayResult.cancelled(), <String>[]),
      );
      final event = EventItem.fromJson(_eventJson);

      final result = await c
          .read(eventTicketCheckoutProvider)
          .payOnline(event, _attendee);

      expect(result.outcome, TicketPurchaseOutcome.cancelled);
      expect(f.sent.map((o) => o.path), ['/events/e1/create-order']);
    });

    test('order refused (sold out): no checkout is opened', () async {
      final f = _fakeClient(
        _backend(
          orderError: (o) => _httpError(
            o,
            400,
            'sold out: event has reached maximum capacity',
          ),
        ),
      );
      final opened = <String>[];
      final c = _container(f.client, _launcher(_paid, opened));

      final result = await c
          .read(eventTicketCheckoutProvider)
          .payOnline(EventItem.fromJson(_eventJson), _attendee);

      expect(result.outcome, TicketPurchaseOutcome.failed);
      expect(result.message, contains('sold out'));
      expect(opened, isEmpty);
    });

    test('paid but verification failed: keeps payment for a retry', () async {
      var failVerify = true;
      final backend = _backend();
      final f = _fakeClient((o) {
        if (o.path == '/events/e1/verify-payment' && failVerify) {
          throw _httpError(o, 500, 'db down');
        }
        return backend(o);
      });
      final c = _container(f.client, _launcher(_paid, <String>[]));
      final event = EventItem.fromJson(_eventJson);
      final checkout = c.read(eventTicketCheckoutProvider);

      final first = await checkout.payOnline(event, _attendee);
      expect(first.outcome, TicketPurchaseOutcome.paidButUnconfirmed);
      expect(first.message, contains('pay_1'));
      expect(first.payment?.paymentId, 'pay_1');

      failVerify = false;
      final retry = await checkout.confirmOnlinePayment(
        event,
        _attendee,
        first.payment!,
      );
      expect(retry.outcome, TicketPurchaseOutcome.success);
      // Only one order and one checkout: the retry re-verifies, never re-pays
      expect(
        f.sent.where((o) => o.path == '/events/e1/create-order').length,
        1,
      );
    });

    test('wallet: server debits and issues; balances reloaded', () async {
      final f = _fakeClient(_backend());
      final c = _container(f.client, _launcher(_paid, <String>[]));

      final result = await c
          .read(eventTicketCheckoutProvider)
          .payWithWallet(EventItem.fromJson(_eventJson), _attendee);

      expect(result.outcome, TicketPurchaseOutcome.success);
      expect(result.ticket?.paymentMethod, 'wallet');
      // (GET /events may follow: the list is refreshed to show the ticket)
      expect(f.sent.where((o) => o.path != '/events').map((o) => o.path), [
        '/events/e1/wallet-checkout',
      ]);
      expect((c.read(walletProvider.notifier) as _Wallet).loads, 1);
    });

    test('wallet refusal shows the server reason', () async {
      final f = _fakeClient(
        _backend(
          walletError: (o) => _httpError(
            o,
            400,
            'insufficient wallet balance: ticket costs ₹499.00',
          ),
        ),
      );
      final c = _container(f.client, _launcher(_paid, <String>[]));

      final result = await c
          .read(eventTicketCheckoutProvider)
          .payWithWallet(EventItem.fromJson(_eventJson), _attendee);

      expect(result.outcome, TicketPurchaseOutcome.failed);
      expect(result.message, contains('insufficient wallet balance'));
    });

    test('wallet timeout is reported as unknown, not as failed', () async {
      final f = _fakeClient(
        _backend(
          walletError: (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
      );
      final c = _container(f.client, _launcher(_paid, <String>[]));

      final result = await c
          .read(eventTicketCheckoutProvider)
          .payWithWallet(EventItem.fromJson(_eventJson), _attendee);

      expect(result.outcome, TicketPurchaseOutcome.outcomeUnknown);
      expect(result.message, EventTicketCheckout.unknownWalletOutcomeMessage);
    });

    test('a success without a ticket is an error, not a ticket', () async {
      final f = _fakeClient(
        (o) => _ok(o, {'message': 'Ticket purchased successfully via wallet'}),
      );
      await expectLater(
        EventRepository(f.client).buyTicketWithWallet('e1', _attendee),
        throwsA(isA<AppValidationException>()),
      );
    });

    test('my tickets: GET /events/my/tickets, null body means none', () async {
      final f = _fakeClient((o) => _ok(o, null));
      expect(await EventRepository(f.client).getMyTickets(), isEmpty);
      expect(f.sent.single.path, '/events/my/tickets');
    });
  });

  group('Event screens', () {
    Future<void> pumpDetail(WidgetTester tester, EventItem event) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: EventDetailScreen(event: event)),
        ),
      );
      await tester.pump();
    }

    testWidgets('paid event offers a ticket with price and seats', (
      tester,
    ) async {
      await pumpDetail(tester, EventItem.fromJson(_eventJson));
      expect(find.text('Buy ticket · ₹499'), findsOneWidget);
      expect(find.text('₹499 per ticket · 12 seats left'), findsOneWidget);
    });

    testWidgets('sold-out event cannot be booked', (tester) async {
      await pumpDetail(
        tester,
        EventItem.fromJson({..._eventJson, 'available_seats': 0}),
      );
      expect(find.text('Sold out'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sold out'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('ticket shows its number and entry QR code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventTicketCard(
                ticket: EventTicket.fromJson(_ticketJson()),
              ),
            ),
          ),
        ),
      );
      expect(find.text('TKT-EVT-123456'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('₹499 · Paid online'), findsOneWidget);
    });
  });

  group('Refund requests (F73)', () {
    test('only debit payments that are not refunds can be disputed', () {
      expect(_txn().canRequestRefund, isTrue);
      expect(_txn(type: 'credit', category: 'topup').canRequestRefund, isFalse);
      expect(_txn(category: 'refund').canRequestRefund, isFalse);
      expect(_txn().title, 'Event ticket');
    });

    test('dispute parses status, reason and admin note', () {
      final d = WalletDispute.fromJson({
        'id': 'd1',
        'transaction_id': 'tx1',
        'amount': 499,
        'category': 'event_ticket',
        'reason': 'duplicate_charge',
        'description': 'Charged twice',
        'status': 'under_review',
        'admin_notes': 'Checking with the bank',
        'created_at': '2026-09-28T10:00:00Z',
      });
      expect(d.reason, DisputeReason.duplicateCharge);
      expect(d.status, DisputeStatus.underReview);
      expect(d.status.isOpen, isTrue);
      expect(d.adminNotes, 'Checking with the bank');
    });

    test('raise: POST /wallet/disputes with the backend fields', () async {
      final f = _fakeClient(
        (o) => Response<dynamic>(
          requestOptions: o,
          statusCode: 201,
          data: <String, dynamic>{
            'id': 'd1',
            'transaction_id': 'tx1',
            'reason': 'duplicate_charge',
            'status': 'pending',
          },
        ),
      );
      final d = await WalletRepository(f.client).createDispute(
        transactionId: 'tx1',
        reason: DisputeReason.duplicateCharge,
        description: '  Charged twice  ',
      );
      expect(d.status, DisputeStatus.pending);
      expect(f.sent.single.path, '/wallet/disputes');
      expect(f.sent.single.data, {
        'transaction_id': 'tx1',
        'reason': 'duplicate_charge',
        'description': 'Charged twice',
      });
    });

    test('raise: 400 shows the reason; 5xx is unknown; 404 unavailable', () {
      Future<void> check(
        DioException Function(RequestOptions) error,
        Matcher matcher,
      ) {
        final f = _fakeClient((o) => throw error(o));
        return expectLater(
          WalletRepository(f.client).createDispute(
            transactionId: 'tx1',
            reason: DisputeReason.other,
            description: 'x',
          ),
          throwsA(matcher),
        );
      }

      return Future.wait([
        check(
          (o) => _httpError(
            o,
            400,
            'a dispute request has already been filed for this transaction',
          ),
          isA<WalletApiException>()
              .having((e) => e.message, 'message', contains('already been'))
              .having((e) => e.isOutcomeUnknown, 'unknown', isFalse),
        ),
        check(
          (o) => _httpError(o, 500, 'boom'),
          isA<WalletApiException>().having(
            (e) => e.isOutcomeUnknown,
            'unknown',
            isTrue,
          ),
        ),
        check(
          (o) => _httpError(o, 404, 'Cannot POST'),
          isA<WalletApiException>().having(
            (e) => e.isBackendPending,
            'pending',
            isTrue,
          ),
        ),
      ]);
    });

    test('list: GET /wallet/my/disputes, {disputes: null} is empty', () async {
      final f = _fakeClient(
        (o) => _ok(o, {'disputes': null, 'total': 0, 'page': 1, 'limit': 50}),
      );
      expect(await WalletRepository(f.client).getMyDisputes(), isEmpty);
      expect(f.sent.single.path, '/wallet/my/disputes');
    });

    testWidgets('refund sheet needs a reason, then submits', (tester) async {
      final f = _fakeClient(
        (o) => Response<dynamic>(
          requestOptions: o,
          statusCode: 201,
          data: <String, dynamic>{'id': 'd1', 'transaction_id': 'tx1'},
        ),
      );
      bool? submitted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(
              WalletRepository(f.client),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    submitted = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => RefundRequestSheet(transaction: _txn()),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Submit stays off until a reason and 10+ characters are given
      final submit = find.widgetWithText(ElevatedButton, 'Submit dispute');
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<DisputeReason>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate Deduction').last);
      await tester.pumpAndSettle();
      expect(
        find.text('The amount was deducted more than once'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Paid');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      expect(f.sent, isEmpty);

      await tester.enterText(find.byType(TextField), 'Paid twice');
      await tester.pump();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(f.sent.single.data, {
        'transaction_id': 'tx1',
        'reason': 'duplicate_charge',
        'description': 'Paid twice',
      });
    });

    testWidgets('dispute card shows status and the team note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DisputeCard(
              dispute: WalletDispute.fromJson({
                'id': 'd1',
                'transaction_id': 'tx1',
                'amount': 499,
                'category': 'event_ticket',
                'reason': 'service_not_provided',
                'status': 'approved',
                'admin_notes': 'Refund approved',
                'resolved_at': '2026-09-29T10:00:00Z',
              }),
            ),
          ),
        ),
      );
      expect(find.text('Event ticket'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Service / Mentorship Not Delivered'), findsOneWidget);
      expect(find.textContaining('Refund approved'), findsOneWidget);
      expect(find.textContaining('added to your wallet'), findsOneWidget);
    });
  });
}
