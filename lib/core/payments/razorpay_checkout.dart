import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Result of one Razorpay checkout attempt.
class RazorpayResult {
  final bool success;
  final bool cancelled;
  final String paymentId;
  final String orderId;
  final String signature;
  final String? errorMessage;

  const RazorpayResult._({
    required this.success,
    this.cancelled = false,
    this.paymentId = '',
    this.orderId = '',
    this.signature = '',
    this.errorMessage,
  });

  factory RazorpayResult.paid({
    required String paymentId,
    required String orderId,
    required String signature,
  }) => RazorpayResult._(
    success: true,
    paymentId: paymentId,
    orderId: orderId,
    signature: signature,
  );

  factory RazorpayResult.cancelled() =>
      const RazorpayResult._(success: false, cancelled: true);

  factory RazorpayResult.failed(String message) =>
      RazorpayResult._(success: false, errorMessage: message);
}

/// Opens the official Razorpay checkout and waits for the outcome.
///
/// IMPORTANT: a successful checkout does NOT mean money was added or a
/// booking was made. The caller must always send [RazorpayResult.paymentId],
/// [RazorpayResult.orderId] and [RazorpayResult.signature] to the backend
/// "verify" endpoint, which checks the signature with the secret key and only
/// then credits the wallet / confirms the booking.
class RazorpayCheckout {
  RazorpayCheckout._();

  static bool _isOpen = false;

  static Future<RazorpayResult> pay({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String description,
    String name = 'KaamMilega',
    String? email,
    String? contact,
    String? preferredMethod, // 'upi' | 'card' | 'netbanking' (optional)
  }) async {
    if (keyId.isEmpty || orderId.isEmpty || amountPaise <= 0) {
      return RazorpayResult.failed(
        'Payment could not be started. Please try again.',
      );
    }
    // Never open two checkouts at once (double taps)
    if (_isOpen) {
      return RazorpayResult.failed('A payment is already in progress.');
    }
    _isOpen = true;

    final completer = Completer<RazorpayResult>();
    final razorpay = Razorpay();

    void finish(RazorpayResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      final paymentId = r.paymentId ?? '';
      final signature = r.signature ?? '';
      if (paymentId.isEmpty || signature.isEmpty) {
        finish(
          RazorpayResult.failed(
            'Payment response was incomplete. If money was deducted, it '
            'will be refunded automatically by Razorpay.',
          ),
        );
        return;
      }
      finish(
        RazorpayResult.paid(
          paymentId: paymentId,
          orderId: r.orderId ?? orderId,
          signature: signature,
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code == Razorpay.PAYMENT_CANCELLED) {
        finish(RazorpayResult.cancelled());
      } else {
        final msg = (r.message ?? '').trim();
        finish(
          RazorpayResult.failed(
            msg.isNotEmpty ? 'Payment failed: $msg' : 'Payment failed.',
          ),
        );
      }
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // External wallets (e.g. Paytm app) cannot be verified by our backend
      finish(
        RazorpayResult.failed(
          'Please pay using UPI, card or net banking inside the checkout.',
        ),
      );
    });

    try {
      razorpay.open({
        'key': keyId,
        'order_id': orderId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': name,
        'description': description,
        'prefill': {
          if (email != null && email.isNotEmpty) 'email': email,
          if (contact != null && contact.isNotEmpty) 'contact': contact,
          if (preferredMethod != null && preferredMethod.isNotEmpty)
            'method': preferredMethod,
        },
        'theme': {'color': '#1A2B8C'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      finish(RazorpayResult.failed('Could not open payment screen: $e'));
    }

    try {
      return await completer.future;
    } finally {
      razorpay.clear();
      _isOpen = false;
    }
  }
}
