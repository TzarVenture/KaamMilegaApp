import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/models/wallet_summary.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/instant_candidate.dart';
import '../repositories/instant_candidate_repository.dart';
import '../services/location_service.dart';

enum InstantActionOutcome {
  success,

  /// Going online needs a pass with gigs left: show the pass sheet.
  passRequired,

  /// No location from the phone: cannot go online.
  noLocation,

  /// Refused or failed; nothing changed.
  failed,

  /// No answer from the server: it may or may not have happened. The
  /// status is reloaded from the server.
  unknown,
}

typedef InstantActionResult = ({InstantActionOutcome outcome, String message});

/// Whether the pass can be paid online ([InstantPassTerms.onlinePaymentLive];
/// replaced in tests).
final instantPassOnlinePaymentProvider = Provider<bool>(
  (ref) => InstantPassTerms.onlinePaymentLive,
);

@immutable
class InstantCandidateState {
  const InstantCandidateState({
    this.isLoading = false,
    this.error,
    this.status,
    this.isBusy = false,
    this.skill = 'All',
    this.pendingPayment,
  });

  final bool isLoading;
  final Object? error;
  final InstantCandidateStatus? status;

  /// A toggle, trade change or purchase is running.
  final bool isBusy;

  /// Primary trade sent with the availability ("All" or a trade name).
  final String skill;

  /// An online pass payment Razorpay completed but the server has not
  /// confirmed yet. Activation can be retried with it; never pay again.
  final RazorpayResult? pendingPayment;

  InstantCandidateState copyWith({
    bool? isLoading,
    Object? error,
    bool clearError = false,
    InstantCandidateStatus? status,
    bool? isBusy,
    String? skill,
    RazorpayResult? pendingPayment,
    bool clearPendingPayment = false,
  }) => InstantCandidateState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    status: status ?? this.status,
    isBusy: isBusy ?? this.isBusy,
    skill: skill ?? this.skill,
    pendingPayment: clearPendingPayment
        ? null
        : (pendingPayment ?? this.pendingPayment),
  );
}

/// InstantMilega "go online" for workers: status from the server, the
/// online toggle (needs an active InstantPass and the phone's location),
/// location updates every 30 s while online, and the pass purchase from
/// the wallet. Lives while the InstantMilega screen is open.
class InstantCandidateNotifier extends Notifier<InstantCandidateState> {
  static const heartbeatEvery = Duration(seconds: 30);

  Timer? _heartbeat;

  InstantCandidateRepository get _repo =>
      ref.read(instantCandidateRepositoryProvider);

  @override
  InstantCandidateState build() {
    ref.onDispose(_stopHeartbeat);
    final signedIn = ref.watch(sessionUserIdProvider) != null;
    if (!signedIn) return const InstantCandidateState();
    Future.microtask(() {
      if (ref.mounted) load();
    });
    return const InstantCandidateState(isLoading: true);
  }

  Future<void> load() async {
    // Account-only API: nothing is requested for guests.
    if (ref.read(sessionUserIdProvider) == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final status = await _repo.getStatus();
      if (!ref.mounted) return;
      _apply(status);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void _apply(InstantCandidateStatus status) {
    state = state.copyWith(
      isLoading: false,
      clearError: true,
      status: status,
      skill: status.activeSkill.isNotEmpty ? status.activeSkill : state.skill,
    );
    status.isOnline ? _startHeartbeat() : _stopHeartbeat();
  }

  Future<InstantActionResult> setOnline(bool online) async {
    final status = state.status;
    if (state.isBusy || status == null) {
      return (outcome: InstantActionOutcome.failed, message: '');
    }
    if (online && !status.canGoOnline) {
      return (
        outcome: InstantActionOutcome.passRequired,
        message: 'An active InstantPass is needed to go online.',
      );
    }
    return _sendAvailability(online: online, skill: state.skill);
  }

  /// Changes the primary trade; while online it is sent to the server at
  /// once so employers see the new trade.
  Future<InstantActionResult> setSkill(String skill) async {
    final status = state.status;
    if (state.isBusy || skill == state.skill) {
      return (outcome: InstantActionOutcome.success, message: '');
    }
    if (status == null || !status.isOnline) {
      state = state.copyWith(skill: skill);
      return (outcome: InstantActionOutcome.success, message: '');
    }
    return _sendAvailability(online: true, skill: skill);
  }

  Future<InstantActionResult> _sendAvailability({
    required bool online,
    required String skill,
  }) async {
    final status = state.status!;
    state = state.copyWith(isBusy: true);
    try {
      // Going online needs the real position; going offline may use the
      // last position the server has.
      var position = await _devicePosition();
      if (!ref.mounted) return _gone;
      if (position == null) {
        if (online) {
          state = state.copyWith(isBusy: false);
          return (
            outcome: InstantActionOutcome.noLocation,
            message:
                'Turn on location and allow it for KaamMilega to go online.',
          );
        }
        position = status.lastLocation;
      }
      if (position == null) {
        state = state.copyWith(isBusy: false);
        return (
          outcome: InstantActionOutcome.failed,
          message: 'Your location is needed. Please try again.',
        );
      }

      await _repo.setAvailability(
        online: online,
        skill: skill,
        hourlyRate: status.hourlyRate,
        lat: position.lat,
        lng: position.lng,
      );
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false, skill: skill);
      _apply(status.copyWith(isOnline: online, activeSkill: skill));
      return (
        outcome: InstantActionOutcome.success,
        message: online
            ? 'You are online. Nearby employers can now find you.'
            : 'You are offline. New gig requests are paused.',
      );
    } on InstantPassRequired catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      unawaited(load());
      return (outcome: InstantActionOutcome.passRequired, message: e.message);
    } on AppValidationException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppAuthException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppException {
      // No answer: show what the server has now instead of guessing.
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      unawaited(load());
      return (
        outcome: InstantActionOutcome.unknown,
        message:
            'Could not update your status. Showing the latest from the '
            'server.',
      );
    }
  }

  /// Pays for the InstantPass from the wallet main balance.
  Future<InstantActionResult> buyPassWithWallet() async {
    if (state.isBusy) {
      return (outcome: InstantActionOutcome.failed, message: '');
    }
    state = state.copyWith(isBusy: true);
    try {
      final message = await _repo.buyPassWithWallet();
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      _afterPurchase();
      return (
        outcome: InstantActionOutcome.success,
        message: message.isNotEmpty
            ? message
            : 'InstantPass is active: ${InstantPassTerms.gigs} gigs.',
      );
    } on AppValidationException catch (e) {
      // Refused (e.g. low balance). Show the server's real state after.
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      _afterPurchase();
      return (
        outcome: InstantActionOutcome.failed,
        message: _sentence(e.message),
      );
    } on AppAuthException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppException {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      _afterPurchase();
      return (
        outcome: InstantActionOutcome.unknown,
        message:
            'We could not confirm your pass purchase. Please check your '
            'pass and wallet before trying again, so you are not charged '
            'twice.',
      );
    }
  }

  /// Pays for the InstantPass online: server order, Razorpay checkout,
  /// then server verification. The pass is active only after the server
  /// confirms it.
  Future<InstantActionResult> buyPassOnline({
    String? email,
    String? contact,
  }) async {
    if (state.isBusy) {
      return (outcome: InstantActionOutcome.failed, message: '');
    }
    state = state.copyWith(isBusy: true);
    final repo = _repo;
    final PaymentOrder order;
    try {
      order = await repo.createPassOrder();
    } on AppAuthException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppException {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false);
      return (
        outcome: InstantActionOutcome.failed,
        message:
            'Online payment could not be started. No money was charged. '
            'Please try again.',
      );
    }
    if (!ref.mounted) return _gone;

    final payment = await ref.read(paymentLauncherProvider)(
      keyId: order.keyId,
      orderId: order.orderId,
      amountPaise: order.amountPaise,
      description:
          'InstantPass (${InstantPassTerms.gigs} gigs, '
          '${InstantPassTerms.validityDays} days)',
      email: email,
      contact: contact,
    );
    if (payment.cancelled || !payment.success) {
      if (ref.mounted) state = state.copyWith(isBusy: false);
      return (
        outcome: InstantActionOutcome.failed,
        message: payment.cancelled
            ? 'Payment cancelled. No money was charged.'
            : (payment.errorMessage ?? 'Payment failed.'),
      );
    }
    return _verifyPayment(repo, payment);
  }

  /// Retries server activation of a payment Razorpay already completed.
  Future<InstantActionResult> retryPassActivation() async {
    final payment = state.pendingPayment;
    if (payment == null || state.isBusy) {
      return (outcome: InstantActionOutcome.failed, message: '');
    }
    state = state.copyWith(isBusy: true);
    return _verifyPayment(_repo, payment);
  }

  Future<InstantActionResult> _verifyPayment(
    InstantCandidateRepository repo,
    RazorpayResult payment,
  ) async {
    try {
      await repo.verifyPassPayment(
        orderId: payment.orderId,
        paymentId: payment.paymentId,
        signature: payment.signature,
      );
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false, clearPendingPayment: true);
      _afterPurchase();
      return (
        outcome: InstantActionOutcome.success,
        message:
            'Payment verified. InstantPass is active: '
            '${InstantPassTerms.gigs} gigs.',
      );
    } on AppException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(isBusy: false, pendingPayment: payment);
      return (
        outcome: InstantActionOutcome.unknown,
        message:
            'Your payment was received but the pass could not be activated '
            'yet (${e.message}). Please do not pay again. Payment ID: '
            '${payment.paymentId}. Try again, or contact support with this '
            'ID.',
      );
    }
  }

  void _afterPurchase() {
    unawaited(load());
    // Balances always come from the server, never changed locally.
    unawaited(ref.read(walletProvider.notifier).loadWallet());
  }

  Future<({double lat, double lng})?> _devicePosition() async {
    final result = await ref.read(locationServiceProvider).currentLocation();
    return switch (result) {
      LocationFound(:final location) => (
        lat: location.latitude,
        lng: location.longitude,
      ),
      LocationFailed() => null,
    };
  }

  void _startHeartbeat() {
    _heartbeat ??= Timer.periodic(heartbeatEvery, (_) => _ping());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _ping() async {
    final position = await _devicePosition();
    if (position == null || !ref.mounted) return;
    try {
      await _repo.pingLocation(lat: position.lat, lng: position.lng);
    } catch (_) {
      // A missed update is retried on the next beat; the status on screen
      // comes from the server, not from these pings.
    }
  }

  static const InstantActionResult _gone = (
    outcome: InstantActionOutcome.failed,
    message: '',
  );

  static String _sentence(String m) {
    final t = m.trim();
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }
}

final instantCandidateProvider =
    NotifierProvider.autoDispose<
      InstantCandidateNotifier,
      InstantCandidateState
    >(InstantCandidateNotifier.new);
