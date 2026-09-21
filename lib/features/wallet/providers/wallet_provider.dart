import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';

class WalletState {
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final bool isActionLoading;
  final String? error;
  final String? actionMessage;

  const WalletState({
    this.transactions = const [],
    this.isLoading = false,
    this.isActionLoading = false,
    this.error,
    this.actionMessage,
  });

  WalletState copyWith({
    List<WalletTransaction>? transactions,
    bool? isLoading,
    bool? isActionLoading,
    String? error,
    String? actionMessage,
  }) {
    return WalletState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      error: error,
      actionMessage: actionMessage,
    );
  }
}

class WalletNotifier extends Notifier<WalletState> {
  late final WalletRepository _repository;

  @override
  WalletState build() {
    _repository = ref.watch(walletRepositoryProvider);
    Future.microtask(() => loadTransactions());
    return const WalletState();
  }

  /// Load user transactions from backend
  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final txns = await _repository.getTransactions();
      state = state.copyWith(isLoading: false, transactions: txns);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Pull-to-refresh wallet data: refreshes user profile from Go backend & transactions
  Future<void> refreshWallet() async {
    await Future.wait([
      ref.read(authProvider.notifier).refreshProfile(),
      loadTransactions(),
    ]);
  }

  /// Initiate Add Money flow
  Future<Map<String, dynamic>?> addMoney({
    required double amount,
    required String paymentMethod,
  }) async {
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

  /// Initiate Withdrawal flow
  Future<Map<String, dynamic>?> withdraw({
    required double amount,
    required String destinationType,
    required String destinationDetail,
  }) async {
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

  /// Initiate Transfer flow
  Future<Map<String, dynamic>?> transfer({
    required double amount,
    required String recipientIdentifier,
    String? note,
  }) async {
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
