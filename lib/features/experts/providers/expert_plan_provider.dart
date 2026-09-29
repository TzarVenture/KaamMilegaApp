import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/models/wallet_summary.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/expert_plan.dart';
import '../repositories/expert_repository.dart';

/// Pro Expert plans with their perks, as the server defines them.
final expertPlansProvider = FutureProvider.autoDispose<List<ExpertPlan>>(
  (ref) => ref.watch(expertRepositoryProvider).getExpertPlans(),
);

/// The signed-in user's Pro Expert plan; no request without a session.
final myExpertSubscriptionProvider =
    FutureProvider.autoDispose<ExpertSubscriptionStatus>((ref) {
      if (ref.watch(sessionUserIdProvider) == null) {
        return ExpertSubscriptionStatus.none;
      }
      return ref.watch(expertRepositoryProvider).getMyExpertSubscription();
    });

/// Opens the payment screen; [RazorpayCheckout.pay] in the app, replaced in
/// tests so no real checkout is ever opened.
typedef ExpertPlanPaymentLauncher = Future<RazorpayResult> Function({
  required String keyId,
  required String orderId,
  required int amountPaise,
  required String description,
  String? email,
  String? contact,
});

final expertPlanPaymentLauncherProvider = Provider<ExpertPlanPaymentLauncher>(
  (ref) => RazorpayCheckout.pay,
);

enum ExpertPlanOutcome {
  /// The server activated the plan.
  success,

  /// The user closed the payment screen; nothing was charged.
  cancelled,

  /// Refused before any money moved (e.g. low balance).
  failed,

  /// Razorpay took the money but the server has not activated the plan yet.
  /// Activation can be retried with [ExpertPlanResult.payment].
  paidButUnconfirmed,

  /// The wallet request got no answer; it may or may not have gone through.
  outcomeUnknown,
}

class ExpertPlanResult {
  final ExpertPlanOutcome outcome;
  final String message;

  /// Set for [ExpertPlanOutcome.paidButUnconfirmed].
  final RazorpayResult? payment;

  const ExpertPlanResult(this.outcome, this.message, {this.payment});
}

/// Buys a Pro Expert plan with Razorpay (create order, pay, server
/// verification) or the wallet main balance. The plan is shown as active
/// only after the server says so.
class ExpertPlanCheckout {
  ExpertPlanCheckout(this._ref);

  final Ref _ref;

  ExpertRepository get _repo => _ref.read(expertRepositoryProvider);

  static const String unknownWalletOutcomeMessage =
      'We could not confirm your plan purchase. Please check your plan '
      'status and wallet before trying again, so you are not charged twice.';

  Future<ExpertPlanResult> payWithWallet(ExpertPlan plan) async {
    try {
      final message = await _repo.buyExpertPlanWithWallet(plan.planType);
      _onActivated();
      return ExpertPlanResult(
        ExpertPlanOutcome.success,
        message.isNotEmpty
            ? message
            : '${plan.priceLabel} was paid from your wallet.',
      );
    } on AppValidationException catch (e) {
      // The server refused (e.g. low balance). Show its real state after.
      _refreshStatus();
      return ExpertPlanResult(ExpertPlanOutcome.failed, _sentence(e.message));
    } on AppAuthException catch (e) {
      return ExpertPlanResult(ExpertPlanOutcome.failed, e.message);
    } on AppNotFoundException {
      return const ExpertPlanResult(
        ExpertPlanOutcome.failed,
        'Pro Expert plans are not available right now. No money was charged.',
      );
    } on AppException {
      // Timeout, dropped connection or server error: the debit may have
      // happened. Show the server's state instead of guessing.
      _refreshStatus();
      return const ExpertPlanResult(
        ExpertPlanOutcome.outcomeUnknown,
        unknownWalletOutcomeMessage,
      );
    }
  }

  Future<ExpertPlanResult> payOnline(
    ExpertPlan plan, {
    String? email,
    String? contact,
  }) async {
    final PaymentOrder order;
    try {
      order = await _repo.createExpertPlanOrder(plan.planType);
    } on AppAuthException catch (e) {
      return ExpertPlanResult(ExpertPlanOutcome.failed, e.message);
    } on AppException {
      return const ExpertPlanResult(
        ExpertPlanOutcome.failed,
        'Online payment could not be started. No money was charged. '
        'Please try again.',
      );
    }

    final payment = await _ref.read(expertPlanPaymentLauncherProvider)(
      keyId: order.keyId,
      orderId: order.orderId,
      amountPaise: order.amountPaise,
      description: plan.name,
      email: email,
      contact: contact,
    );
    if (payment.cancelled) {
      return const ExpertPlanResult(
        ExpertPlanOutcome.cancelled,
        'Payment cancelled. No money was charged.',
      );
    }
    if (!payment.success) {
      return ExpertPlanResult(
        ExpertPlanOutcome.failed,
        payment.errorMessage ?? 'Payment failed.',
      );
    }
    return confirmOnlinePayment(plan, payment);
  }

  /// Asks the server to verify a completed Razorpay payment and activate
  /// the plan.
  Future<ExpertPlanResult> confirmOnlinePayment(
    ExpertPlan plan,
    RazorpayResult payment,
  ) async {
    try {
      final message = await _repo.verifyExpertPlanPayment(
        planType: plan.planType,
        orderId: payment.orderId,
        paymentId: payment.paymentId,
        signature: payment.signature,
      );
      _onActivated();
      return ExpertPlanResult(
        ExpertPlanOutcome.success,
        message.isNotEmpty ? message : 'Payment verified. Your plan is active.',
      );
    } on AppException catch (e) {
      return ExpertPlanResult(
        ExpertPlanOutcome.paidButUnconfirmed,
        'Your payment was received but the plan could not be activated yet '
        '(${e.message}). Please do not pay again. Payment ID: '
        '${payment.paymentId}. Try again, or contact support with this ID.',
        payment: payment,
      );
    }
  }

  void _onActivated() {
    _refreshStatus();
    // Subscribing adds the expert role on the server.
    unawaited(_ref.read(authProvider.notifier).refreshProfile());
  }

  void _refreshStatus() {
    _ref.invalidate(myExpertSubscriptionProvider);
    // Balances always come from the server, never changed locally.
    unawaited(_ref.read(walletProvider.notifier).loadWallet());
  }

  static String _sentence(String message) {
    final m = message.trim();
    if (m.isEmpty) return 'The payment could not be completed.';
    return '${m[0].toUpperCase()}${m.substring(1)}';
  }
}

final expertPlanCheckoutProvider = Provider<ExpertPlanCheckout>(
  ExpertPlanCheckout.new,
);
