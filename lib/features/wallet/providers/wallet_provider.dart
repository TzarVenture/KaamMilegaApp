import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';

class WalletState {
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final bool isActionLoading;
  final bool isOffline;
  final String? error;
  final String? actionMessage;
  final DateTime? cachedTimestamp;

  const WalletState({
    this.transactions = const [],
    this.isLoading = false,
    this.isActionLoading = false,
    this.isOffline = false,
    this.error,
    this.actionMessage,
    this.cachedTimestamp,
  });

  WalletState copyWith({
    List<WalletTransaction>? transactions,
    bool? isLoading,
    bool? isActionLoading,
    bool? isOffline,
    String? error,
    String? actionMessage,
    DateTime? cachedTimestamp,
  }) {
    return WalletState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isOffline: isOffline ?? this.isOffline,
      error: error,
      actionMessage: actionMessage,
      cachedTimestamp: cachedTimestamp,
    );
  }
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

    // Load initial cached snapshot if any
    final cached = LocalStorage.getCachedWallet();
    DateTime? initialTime;
    if (cached.data != null) {
      initialTime = cached.timestamp;
    }

    Future.microtask(() => loadTransactions());
    return WalletState(cachedTimestamp: initialTime);
  }

  /// Load user transactions from backend with offline fallback
  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final txns = await _repository.getTransactions();
      if (!ref.mounted) return;

      // Cache transaction snapshot
      try {
        final txList = txns.map((t) => t.toJson()).toList();
        LocalStorage.saveCachedWallet({'transactions': txList});
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        transactions: txns,
        isOffline: false,
        cachedTimestamp: null,
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

  /// Pull-to-refresh wallet data: refreshes user profile & transactions
  Future<void> refreshWallet() async {
    if (!ref.mounted) return;
    await Future.wait([
      ref.read(authProvider.notifier).refreshProfile(),
      loadTransactions(),
    ]);
  }

  /// Initiate Add Money flow (strictly requires active network & prevents duplicate submission)
  Future<Map<String, dynamic>?> addMoney({
    required double amount,
    required String paymentMethod,
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
      final res = await _repository.initiateAddMoney(
        amount: amount,
        paymentMethod: paymentMethod,
      );
      state = state.copyWith(isActionLoading: false);
      await refreshWallet();
      return res;
    } on WalletApiException catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Initiate Withdrawal flow (strictly requires active network & prevents duplicate submission)
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
    } on WalletApiException catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Initiate Transfer flow (strictly requires active network & prevents duplicate submission)
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
    } on WalletApiException catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
