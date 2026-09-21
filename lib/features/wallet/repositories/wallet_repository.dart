import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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

class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository(this._apiClient);

  /// Fetch transactions from backend ledger.
  /// If the backend endpoint (/api/wallet/transactions) has not been deployed yet,
  /// returns an empty list without throwing errors or injecting mock data.
  Future<List<WalletTransaction>> getTransactions() async {
    try {
      final response = await _apiClient.get('/api/wallet/transactions');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List list = [];
        if (data is Map && data['data'] is List) {
          list = data['data'] as List;
        } else if (data is List) {
          list = data;
        }
        return list
            .whereType<Map<String, dynamic>>()
            .map(WalletTransaction.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      // If endpoint doesn't exist yet on Go backend (404/501)
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 501 ||
          e.response?.statusCode == 405) {
        return [];
      }
      // Return empty list on connection/server issues to maintain clean state
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Request to add funds via payment gateway.
  /// When backend gateway microservice is integrated, this will return the gateway order intent.
  Future<Map<String, dynamic>> initiateAddMoney({
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/wallet/add-money',
        data: {'amount': amount, 'payment_method': paymentMethod},
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      throw const WalletApiException('Invalid response from payment service');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 501 ||
          e.response?.statusCode == 405) {
        throw const WalletApiException(
          'Payment Gateway API is not yet mounted on the backend. Please connect your Razorpay/Cashfree gateway in km-backend.',
          isBackendPending: true,
        );
      }
      throw WalletApiException(
        e.error?.toString() ?? 'Failed to initiate payment',
      );
    }
  }

  /// Request withdrawal to bank or UPI.
  Future<Map<String, dynamic>> initiateWithdrawal({
    required double amount,
    required String destinationType,
    required String destinationDetail,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/wallet/withdraw',
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 501 ||
          e.response?.statusCode == 405) {
        throw const WalletApiException(
          'Payout/Settlement microservice is not yet mounted on the backend. Please implement /api/wallet/withdraw in km-backend.',
          isBackendPending: true,
        );
      }
      throw WalletApiException(
        e.error?.toString() ?? 'Withdrawal request failed',
      );
    }
  }

  /// Request P2P transfer to another KaamMilega user.
  Future<Map<String, dynamic>> initiateTransfer({
    required double amount,
    required String recipientIdentifier,
    String? note,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/wallet/transfer',
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 501 ||
          e.response?.statusCode == 405) {
        throw const WalletApiException(
          'Transfer microservice is not yet mounted on the backend. Please implement /api/wallet/transfer in km-backend.',
          isBackendPending: true,
        );
      }
      throw WalletApiException(
        e.error?.toString() ?? 'Transfer request failed',
      );
    }
  }
}
