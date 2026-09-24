import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WalletRepository(apiClient);
});

class WalletApiException implements Exception {
  final String message;
  final bool isBackendPending;

  const WalletApiException(this.message, {this.isBackendPending = false});

  @override
  String toString() => message;
}

/// Wallet API client (backend `internal/features/wallet`).
///
/// Live: balance, transactions, Razorpay top-up (create order + verify).
/// Not built yet: withdraw, transfer -> HTTP 404 -> "coming soon".
/// ApiClient turns HTTP 404 into [AppNotFoundException]; here that becomes a
/// [WalletApiException] with `isBackendPending: true` so screens show a
/// friendly "coming soon" state (e.g. if the server is not updated yet).
class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository(this._apiClient);

  static const String comingSoonMessage =
      'KaamMilega Wallet is coming soon. Payments, withdrawals and transfers '
      'will be available here once the wallet goes live.';

  /// Balances (GET /wallet/balance)
  Future<WalletSummary> getSummary() async {
    try {
      final response = await _apiClient.get(ApiConstants.walletBalance);
      final data = response.data;
      if (data is Map<String, dynamic>) return WalletSummary.fromJson(data);
      throw const WalletApiException('Invalid response from wallet service');
    } on AppNotFoundException {
      throw const WalletApiException(comingSoonMessage, isBackendPending: true);
    }
  }

  /// Ledger entries, newest first (GET /wallet/transactions).
  /// Backend response: {transactions: [...], total, page, limit, total_pages}
  Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.walletTransactions,
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      List list = [];
      if (data is Map && data['transactions'] is List) {
        list = data['transactions'] as List;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else if (data is List) {
        list = data;
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList();
    } on AppNotFoundException {
      throw const WalletApiException(comingSoonMessage, isBackendPending: true);
    }
  }

  /// Step 1 of Add Money: create a Razorpay order on the server
  /// (POST /wallet/topup/create-order). Server limits: ₹10 – ₹1,00,000.
  Future<PaymentOrder> createTopupOrder(double amount) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.walletTopupCreateOrder,
        data: {'amount': amount},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final order = PaymentOrder.fromJson(data);
        if (order.isValid) return order;
      }
      throw const WalletApiException(
        'Could not start the payment. Please try again.',
      );
    } on AppNotFoundException {
      throw const WalletApiException(
        'Adding money to your wallet is coming soon. No amount has been '
        'charged.',
        isBackendPending: true,
      );
    } on AppValidationException catch (e) {
      // e.g. "minimum recharge amount is ₹10" or gateway not configured
      throw WalletApiException(e.message);
    }
  }

  /// Step 3 of Add Money: let the server verify the Razorpay signature and
  /// credit the wallet (POST /wallet/topup/verify). Returns fresh balances.
  Future<WalletSummary?> verifyTopup({
    required String orderId,
    required String paymentId,
    required String signature,
    required double amount,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.walletTopupVerify,
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'amount': amount,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['wallet'] is Map<String, dynamic>) {
      return WalletSummary.fromJson(data['wallet'] as Map<String, dynamic>);
    }
    return null;
  }

  /// Request withdrawal to bank or UPI (not built on backend yet).
  Future<Map<String, dynamic>> initiateWithdrawal({
    required double amount,
    required String destinationType,
    required String destinationDetail,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.walletWithdraw,
        data: {
          'amount': amount,
          'destination_type': destinationType,
          'destination_detail': destinationDetail,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      throw const WalletApiException('Invalid response from payout service');
    } on AppNotFoundException {
      throw const WalletApiException(
        'Withdrawals are coming soon. No withdrawal request has been placed.',
        isBackendPending: true,
      );
    }
  }

  /// Request P2P transfer to another KaamMilega user (not built yet).
  Future<Map<String, dynamic>> initiateTransfer({
    required double amount,
    required String recipientIdentifier,
    String? note,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.walletTransfer,
        data: {
          'amount': amount,
          'recipient': recipientIdentifier,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      throw const WalletApiException('Invalid response from transfer service');
    } on AppNotFoundException {
      throw const WalletApiException(
        'Wallet transfers are coming soon. No money has been sent.',
        isBackendPending: true,
      );
    }
  }
}
