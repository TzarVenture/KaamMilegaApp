import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/response_list.dart';
import '../../wallet/models/wallet_summary.dart';
import '../models/instant_candidate.dart';
import '../models/spot_gig.dart';

/// Going online needs an active InstantPass with gigs left: the server
/// answered HTTP 402 with `requires_pass`.
class InstantPassRequired implements Exception {
  const InstantPassRequired(this.message);
  final String message;

  @override
  String toString() => message;
}

/// InstantMilega candidate APIs (/instant-work, login required).
class InstantCandidateRepository {
  InstantCandidateRepository(this._client);

  final ApiClient _client;

  Future<InstantCandidateStatus> getStatus() async {
    final response = await _client.get(ApiConstants.instantCandidateStatus);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return InstantCandidateStatus.fromJson(data);
    }
    throw const AppValidationException(
      'Unexpected response from server. Please try again.',
    );
  }

  /// Online / offline (POST /instant-work/availability). Going online is
  /// refused with [InstantPassRequired] when there is no usable pass.
  Future<void> setAvailability({
    required bool online,
    required String skill,
    required double hourlyRate,
    required double lat,
    required double lng,
  }) async {
    try {
      await _client.post(
        ApiConstants.instantAvailability,
        data: {
          'is_free_now': online,
          'skill': skill,
          'hourly_rate': hourlyRate,
          'lat': lat,
          'lng': lng,
        },
      );
    } on AppValidationException catch (e) {
      if (e.validationErrors?['requires_pass'] == true) {
        throw InstantPassRequired(_sentence(e.message));
      }
      rethrow;
    }
  }

  /// Location update while online (POST /instant-work/location).
  Future<void> pingLocation({required double lat, required double lng}) =>
      _client.post(
        ApiConstants.instantLocation,
        data: {'lat': lat, 'lng': lng},
      );

  /// Buys the pass from the wallet main balance
  /// (POST /instant-work/pass/pay-wallet). Returns the server's message.
  Future<String> buyPassWithWallet() async {
    final response = await _client.post(ApiConstants.instantPassPayWallet);
    final data = response.data;
    if (data is Map<String, dynamic> && data['pass'] is Map) {
      return data['message']?.toString().trim() ?? '';
    }
    throw const AppValidationException(
      'Unexpected response from server. Please check your pass status.',
    );
  }

  /// Starts an online (Razorpay) pass payment
  /// (POST /instant-work/pass/order). Here the server sends `amount` in
  /// paise (9900) and `pass_inr` in rupees.
  Future<PaymentOrder> createPassOrder() async {
    final response = await _client.post(ApiConstants.instantPassOrder);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final paise = data['amount'] is num
          ? (data['amount'] as num).round()
          : 0;
      final order = PaymentOrder(
        orderId: data['order_id']?.toString() ?? '',
        amount: data['pass_inr'] is num
            ? (data['pass_inr'] as num).toDouble()
            : paise / 100,
        amountPaise: paise,
        keyId: data['key_id']?.toString() ?? '',
      );
      if (order.orderId.isNotEmpty &&
          order.keyId.isNotEmpty &&
          order.amountPaise > 0) {
        return order;
      }
    }
    throw const AppValidationException(
      'Online payment could not be started. No money was charged.',
    );
  }

  /// Sends a completed Razorpay payment for server verification
  /// (POST /instant-work/pass/verify). The pass is active only after this
  /// succeeds.
  Future<void> verifyPassPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await _client.post(
      ApiConstants.instantPassVerify,
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    if (response.data is! Map) {
      throw const AppValidationException(
        'Unexpected response from server. Please check your pass status.',
      );
    }
  }

  // --- Spot gigs ---

  /// Open spot gigs near [lat]/[lng], newest first
  /// (GET /instant-work/candidate/feed; the server caps it at 20).
  /// [skill] "All" (or empty) means every trade.
  Future<List<SpotGig>> getNearbyGigs({
    required double lat,
    required double lng,
    String skill = '',
    double radiusKm = 15,
  }) async {
    final trade = skill.trim();
    final response = await _client.get(
      ApiConstants.instantCandidateFeed,
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (trade.isNotEmpty && trade.toLowerCase() != 'all') 'skill': trade,
      },
    );
    return readListResponse(response.data)
        .map(SpotGig.fromJson)
        .where((g) => g.id.isNotEmpty)
        .toList();
  }

  /// Claims a gig (POST /instant-work/claim). Uses one pass gig.
  /// [InstantPassRequired] when there is no pass left; the server's reason
  /// (already taken, expired) as [AppValidationException] otherwise.
  Future<SpotGig> claimGig(String jobId) async {
    try {
      final response = await _client.post(
        ApiConstants.instantClaim,
        data: {'job_id': jobId},
      );
      return _gigFrom(response.data);
    } on AppValidationException catch (e) {
      if (e.validationErrors?['requires_pass'] == true) {
        throw InstantPassRequired(_sentence(e.message));
      }
      throw AppValidationException(_sentence(e.message));
    }
  }

  /// The user's claimed gig that is not closed yet, or null
  /// (GET /instant-work/candidate/active-job; `null` = none).
  Future<SpotGig?> getActiveGig() async {
    final response = await _client.get(ApiConstants.instantActiveJob);
    final data = response.data;
    if (data == null || (data is String && data.trim().isEmpty)) return null;
    return _gigFrom(data);
  }

  /// Marks the claimed gig as done (PUT /instant-work/jobs/:id/complete);
  /// the employer then confirms and the pay reaches the wallet.
  Future<SpotGig> completeGig(String jobId) async {
    final response = await _client.put(
      '${ApiConstants.instantJobs}$jobId/complete',
    );
    return _gigFrom(response.data);
  }

  static SpotGig _gigFrom(dynamic data) {
    if (data is Map<String, dynamic>) {
      final gig = SpotGig.fromJson(data);
      if (gig.id.isNotEmpty) return gig;
    }
    throw const AppValidationException(
      'Unexpected response from server. Please try again.',
    );
  }

  static String _sentence(String m) {
    final t = m.trim();
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }
}

final instantCandidateRepositoryProvider = Provider<InstantCandidateRepository>(
  (ref) => InstantCandidateRepository(ref.watch(apiClientProvider)),
);
