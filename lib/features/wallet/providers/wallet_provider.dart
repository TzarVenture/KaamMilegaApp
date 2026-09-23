import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/network_status.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';

class WalletState {
  final WalletSummary? summary;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final bool isActionLoading;
  final bool isOffline;
  final String? error;
  final String? actionMessage;
  final DateTime? cachedTimestamp;

  /// True while the wallet service is not live on the backend (HTTP 404)
  final bool isComingSoon;

  const WalletState({
    this.summary,
    this.transactions = const [],
    this.isLoading = false,
    this.isActionLoading = false,
    this.isOffline = false,
    this.error,
    this.actionMessage,
    this.cachedTimestamp,
    this.isComingSoon = false,
  });

  WalletState copyWith({
    WalletSummary? summary,
    List<WalletTransaction>? transactions,
    bool? isLoading,
    bool? isActionLoading,
    bool? isOffline,
    String? error,
    String? actionMessage,
    DateTime? cachedTimestamp,
    bool? isComingSoon,
  }) {
    return WalletState(
      summary: summary ?? this.summary,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isOffline: isOffline ?? this.isOffline,
      error: error,
      actionMessage: actionMessage,
      cachedTimestamp: cachedTimestamp,
      isComingSoon: isComingSoon ?? this.isComingSoon,
    );
  }
}

/// Outcome of an Add Money attempt, shown by the Add Money screen.
enum TopupOutcome { success, cancelled, failed, comingSoon, paidButUnverified }

class TopupResult {
  final TopupOutcome outcome;
  final String message;
  const TopupResult(this.outcome, this.message);
}

class WalletNotifier extends Notifier<WalletState> {
  late final WalletRepository _repository;

  @override
  WalletState build() {
    _repository = ref.watch(walletRepositoryProvider);

    // Auto-refresh when internet returns
    ref.listen<NetworkStatus>(networkStatusProvider, (prev, next) {
      if (prev == NetworkStatus.offline && next == NetworkStatus.online) {
        refreshWallet();
      }
    });

    // Load after login; wipe on logout (never show another user's wallet)
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasIn = prev?.isAuthenticated ?? false;
      if (!wasIn && next.isAuthenticated) {
        loadWallet();
      } else if (wasIn && !next.isAuthenticated) {
        state = const WalletState();
      }
    });

    // Show the last known balances instantly (read-only, marked as cached)
    WalletSummary? cachedSummary;
    List<WalletTransaction> cachedTxns = const [];
    DateTime? cachedTime;
    final cached = LocalStorage.getCachedWallet();
    if (cached.data != null) {
      try {
        final s = cached.data!['summary'];
        if (s is Map<String, dynamic>) cachedSummary = WalletSummary.fromJson(s);
        final t = cached.data!['transactions'];
        if (t is List) {
          cachedTxns = t
              .whereType<Map<String, dynamic>>()
              .map(WalletTransaction.fromJson)
              .toList();
        }
        cachedTime = cached.timestamp;
      } catch (_) {}
    }

    Future.microtask(() => loadWallet());
    return WalletState(
      summary: cachedSummary,
      transactions: cachedTxns,
      cachedTimestamp: cachedTime,
    );
  }

  /// Load balances + transactions from the backend
  Future<void> loadWallet() async {
    if (!ref.read(authProvider).isAuthenticated) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      cachedTimestamp: state.cachedTimestamp,
    );
    try {
      final results = await Future.wait([
        _repository.getSummary(),
        _repository.getTransactions(),
      ]);
      if (!ref.mounted) return;
      final summary = results[0] as WalletSummary;
      final txns = results[1] as List<WalletTransaction>;

      try {
        LocalStorage.saveCachedWallet({
          'summary': summary.toJson(),
          'transactions': txns.map((t) => t.toJson()).toList(),
        });
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        summary: summary,
        transactions: txns,
        isOffline: false,
        cachedTimestamp: null,
        isComingSoon: false,
      );
    } on WalletApiException catch (e) {
      if (!ref.mounted) return;
      // Wallet service not live yet: show "coming soon", not an error
      state = state.copyWith(
        isLoading: false,
        isOffline: false,
        isComingSoon: e.isBackendPending,
        error: e.isBackendPending ? null : e.message,
        cachedTimestamp: state.cachedTimestamp,
      );
    } catch (e) {
      if (!ref.mounted) return;
      final isOffline = !ConnectivityService().isOnline;
      state = state.copyWith(
        isLoading: false,
        isOffline: isOffline,
        error: isOffline ? null : e.toString(),
        cachedTimestamp: isOffline
            ? (state.cachedTimestamp ?? DateTime.now())
            : null,
      );
    }
  }

  /// Kept for existing callers (transactions screen pull-to-refresh)
  Future<void> loadTransactions() => loadWallet();

  /// Pull-to-refresh
  Future<void> refreshWallet() async {
    if (!ref.mounted) return;
    await loadWallet();
  }

  /// Add Money: 1) server creates a Razorpay order, 2) Razorpay checkout,
  /// 3) server verifies the payment signature and credits the wallet.
  /// The wallet is only credited by the server in step 3.
  Future<TopupResult> addMoney({
    required double amount,
    String? preferredMethod,
  }) async {
    if (!ConnectivityService().isOnline) {
      return const TopupResult(
        TopupOutcome.failed,
        'Internet connection required to add money.',
      );
    }
    if (state.isActionLoading) {
      return const TopupResult(
        TopupOutcome.failed,
        'A payment is already being processed. Please wait.',
      );
    }

    state = state.copyWith(
      isActionLoading: true,
      error: null,
      cachedTimestamp: state.cachedTimestamp,
    );
    try {
      // 1. Create order on the server
      final order = await _repository.createTopupOrder(amount);

      // 2. Razorpay checkout
      final user = ref.read(authProvider).user;
      final payment = await RazorpayCheckout.pay(
        keyId: order.keyId,
        orderId: order.orderId,
        amountPaise: order.amountPaise,
        description: 'Add ₹${order.amount.toStringAsFixed(0)} to wallet',
        email: user?.email,
        contact: user?.mobile,
        preferredMethod: preferredMethod,
      );
      if (payment.cancelled) {
        return const TopupResult(
          TopupOutcome.cancelled,
          'Payment cancelled. No money was added or charged.',
        );
      }
      if (!payment.success) {
        return TopupResult(
          TopupOutcome.failed,
          payment.errorMessage ?? 'Payment failed.',
        );
      }

      // 3. Verify on the server (this is what actually credits the wallet)
      try {
        final fresh = await _repository.verifyTopup(
          orderId: payment.orderId,
          paymentId: payment.paymentId,
          signature: payment.signature,
          amount: order.amount,
        );
        if (fresh != null && ref.mounted) {
          state = state.copyWith(summary: fresh);
        }
      } on AppException catch (e) {
        await loadWallet();
        return TopupResult(
          TopupOutcome.paidButUnverified,
          'Your payment was received but could not be confirmed yet '
          '(${e.message}). Please do not pay again. Payment ID: '
          '${payment.paymentId}. If your balance does not update, contact '
          'support with this ID.',
        );
      }

      await loadWallet();
      return TopupResult(
        TopupOutcome.success,
        '₹${order.amount.toStringAsFixed(0)} added to your wallet.',
      );
    } on WalletApiException catch (e) {
      return TopupResult(
        e.isBackendPending ? TopupOutcome.comingSoon : TopupOutcome.failed,
        e.message,
      );
    } on AppException catch (e) {
      return TopupResult(TopupOutcome.failed, e.message);
    } catch (e) {
      return TopupResult(TopupOutcome.failed, e.toString());
    } finally {
      if (ref.mounted) {
        state = state.copyWith(
          isActionLoading: false,
          cachedTimestamp: state.cachedTimestamp,
        );
      }
    }
  }

  /// Withdrawal (backend not built yet -> WalletApiException pending)
  Future<Map<String, dynamic>?> withdraw({
    required double amount,
    required String destinationType,
    required String destinationDetail,
  }) async {
    if (!ConnectivityService().isOnline) {
      throw const AppNetworkException(
        'Internet connection required to perform this transaction.',
      );
    }
    if (state.isActionLoading) {
      throw const AppValidationException(
        'A transaction is already being processed. Please wait.',
      );
    }
    state = state.copyWith(isActionLoading: true, error: null);
    try {
      final res = await _repository.initiateWithdrawal(
        amount: amount,
        destinationType: destinationType,
        destinationDetail: destinationDetail,
      );
      state = state.copyWith(isActionLoading: false);
      await refreshWallet();
      return res;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Transfer (backend not built yet -> WalletApiException pending)
  Future<Map<String, dynamic>?> transfer({
    required double amount,
    required String recipientIdentifier,
    String? note,
  }) async {
    if (!ConnectivityService().isOnline) {
      throw const AppNetworkException(
        'Internet connection required to perform this transaction.',
      );
    }
    if (state.isActionLoading) {
      throw const AppValidationException(
        'A transaction is already being processed. Please wait.',
      );
    }
    state = state.copyWith(isActionLoading: true, error: null);
    try {
      final res = await _repository.initiateTransfer(
        amount: amount,
        recipientIdentifier: recipientIdentifier,
        note: note,
      );
      state = state.copyWith(isActionLoading: false);
      await refreshWallet();
      return res;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
