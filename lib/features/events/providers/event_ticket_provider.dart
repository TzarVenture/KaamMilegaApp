import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/models/wallet_summary.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/event.dart';
import '../models/event_ticket.dart';
import '../repositories/event_repository.dart';
import 'event_provider.dart';

/// Confirmed tickets of the signed-in user, newest first
/// (GET /events/my/tickets). Loaded fresh each time a screen needs it, and
/// no request without a session.
final myEventTicketsProvider = FutureProvider.autoDispose<List<EventTicket>>((
  ref,
) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <EventTicket>[];
  }
  return ref.watch(eventRepositoryProvider).getMyTickets();
});

/// Opens the payment screen; [RazorpayCheckout.pay] in the app, replaced in
/// tests so no real checkout is ever opened.
typedef TicketPaymentLauncher = Future<RazorpayResult> Function({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String description,
  String? email,
  String? contact,
});

final ticketPaymentLauncherProvider = Provider<TicketPaymentLauncher>(
  (ref) => RazorpayCheckout.pay,
);

enum TicketPurchaseOutcome {
  /// The server issued the ticket.
  success,

  /// The user closed the payment screen; nothing was charged.
  cancelled,

  /// Refused before any money moved (e.g. sold out, low balance).
  failed,

  /// Razorpay took the money but the server has not issued the ticket yet.
  /// Confirmation can be retried with [TicketPurchaseResult.payment].
  paidButUnconfirmed,

  /// The wallet request got no answer; it may or may not have gone through.
  outcomeUnknown,
}

class TicketPurchaseResult {
  final TicketPurchaseOutcome outcome;
  final String message;
  final EventTicket? ticket;

  /// Set for [TicketPurchaseOutcome.paidButUnconfirmed].
  final RazorpayResult? payment;

  const TicketPurchaseResult(
    this.outcome,
    this.message, {
    this.ticket,
    this.payment,
  });

  bool get isSuccess => outcome == TicketPurchaseOutcome.success;
}

/// Paid event tickets (backend F63): Razorpay (create order, pay, server
/// verification) or the wallet main balance. A ticket is shown only after
/// the server has issued it; nothing is marked as bought locally before.
class EventTicketCheckout {
  EventTicketCheckout(this._ref);

  final Ref _ref;

  EventRepository get _repo => _ref.read(eventRepositoryProvider);

  static const String unknownWalletOutcomeMessage =
      'We could not confirm your ticket purchase. Please check My Tickets '
      'and your wallet before trying again, so you are not charged twice.';

  Future<TicketPurchaseResult> payWithWallet(
    EventItem event,
    EventAttendee attendee,
  ) async {
    try {
      final result = await _repo.buyTicketWithWallet(event.id, attendee);
      _onIssued(event.id);
      _refreshWallet();
      return TicketPurchaseResult(
        TicketPurchaseOutcome.success,
        '${event.priceLabel} was paid from your wallet.',
        ticket: result.ticket,
      );
    } on AppValidationException catch (e) {
      // The server refused (sold out, low balance, already booked, ...).
      return TicketPurchaseResult(TicketPurchaseOutcome.failed, e.message);
    } on AppAuthException catch (e) {
      return TicketPurchaseResult(TicketPurchaseOutcome.failed, e.message);
    } on AppNotFoundException {
      return const TicketPurchaseResult(
        TicketPurchaseOutcome.failed,
        'Ticket booking is not available right now. No money was charged.',
      );
    } on AppException {
      // Timeout, dropped connection or server error: the debit may have
      // happened. Show the server's state instead of guessing.
      _ref.invalidate(myEventTicketsProvider);
      _refreshWallet();
      return const TicketPurchaseResult(
        TicketPurchaseOutcome.outcomeUnknown,
        unknownWalletOutcomeMessage,
      );
    }
  }

  Future<TicketPurchaseResult> payOnline(
    EventItem event,
    EventAttendee attendee,
  ) async {
    final PaymentOrder order;
    try {
      order = await _repo.createTicketOrder(event.id, attendee);
    } on AppNotFoundException {
      return const TicketPurchaseResult(
        TicketPurchaseOutcome.failed,
        'Ticket booking is not available right now. No money was charged.',
      );
    } on AppException catch (e) {
      return TicketPurchaseResult(TicketPurchaseOutcome.failed, e.message);
    }

    final payment = await _ref.read(ticketPaymentLauncherProvider)(
      keyId: order.keyId,
      orderId: order.orderId,
      amountPaise: order.amountPaise,
      description: 'Ticket: ${event.title}',
      email: attendee.email,
      contact: attendee.phone.trim().isEmpty ? null : attendee.phone.trim(),
    );
    if (payment.cancelled) {
      return const TicketPurchaseResult(
        TicketPurchaseOutcome.cancelled,
        'Payment cancelled. No money was charged.',
      );
    }
    if (!payment.success) {
      return TicketPurchaseResult(
        TicketPurchaseOutcome.failed,
        payment.errorMessage ?? 'Payment failed.',
      );
    }
    return confirmOnlinePayment(event, attendee, payment);
  }

  /// Asks the server to verify a completed Razorpay payment and issue the
  /// ticket. Can be retried: the server returns the ticket it already
  /// issued for this event instead of a second one.
  Future<TicketPurchaseResult> confirmOnlinePayment(
    EventItem event,
    EventAttendee attendee,
    RazorpayResult payment,
  ) async {
    try {
      final ticket = await _repo.verifyTicketPayment(
        eventId: event.id,
        orderId: payment.orderId,
        paymentId: payment.paymentId,
        signature: payment.signature,
        attendee: attendee,
      );
      _onIssued(event.id);
      return TicketPurchaseResult(
        TicketPurchaseOutcome.success,
        'Payment verified. Your ticket is confirmed.',
        ticket: ticket,
      );
    } on AppException catch (e) {
      return TicketPurchaseResult(
        TicketPurchaseOutcome.paidButUnconfirmed,
        'Your payment was received but the ticket could not be issued yet '
        '(${e.message}). Please do not pay again. Payment ID: '
        '${payment.paymentId}. Try again, or contact support with this ID.',
        payment: payment,
      );
    }
  }

  void _onIssued(String eventId) {
    _ref.read(eventsProvider.notifier).markRegistered(eventId);
    _ref.invalidate(myEventTicketsProvider);
  }

  void _refreshWallet() {
    // Balances always come from the server, never changed locally.
    unawaited(_ref.read(walletProvider.notifier).loadWallet());
  }
}

final eventTicketCheckoutProvider = Provider<EventTicketCheckout>(
  EventTicketCheckout.new,
);
