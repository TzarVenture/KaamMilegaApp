import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/response_list.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/models/wallet_summary.dart';
import '../models/booking.dart';
import '../models/expert_profile.dart';

final expertRepositoryProvider = Provider<ExpertRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ExpertRepository(apiClient);
});

class ExpertRepository {
  final ApiClient _apiClient;

  ExpertRepository(this._apiClient);

  /// Fetch list of mentors & experts from /mentorships
  Future<List<ExpertItem>> getExperts({String? category, String? query}) async {
    final response = await _apiClient.get(
      ApiConstants.mentorships,
      queryParameters: {
        if (category != null && category.isNotEmpty && category != 'All')
          'category': category,
      },
    );

    if (response.data != null) {
      final data = response.data;
      List list = [];
      if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else if (data is List) {
        list = data;
      }

      final items = list
          .whereType<Map>()
          .map((e) => ExpertItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        return items.where((item) {
          return item.title.toLowerCase().contains(q) ||
              item.expertName.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q);
        }).toList();
      }

      return items;
    }
    return [];
  }

  /// Fetch single expert details from /mentorships/:id
  Future<ExpertItem?> getExpertById(String id) async {
    final response = await _apiClient.get('${ApiConstants.mentorships}/$id');
    if (response.data is Map) {
      return ExpertItem.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    return null;
  }

  /// Booking body shared by all booking endpoints.
  /// `scheduled_at` MUST include a timezone (UTC "...Z"): the Go backend
  /// rejects times without one. (Previously local time without timezone was
  /// sent, which the server could not parse.)
  Map<String, dynamic> _bookingBody(
    String mentorshipId,
    DateTime scheduledAt,
    String? notes,
  ) => {
    'mentorship_id': mentorshipId,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    if (notes != null && notes.isNotEmpty) 'notes': notes,
  };

  /// Free session request (POST /mentorships/book). Throws AppException on
  /// failure so the screen can show the real reason.
  Future<void> bookSession({
    required String mentorshipId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    await _apiClient.post(
      '${ApiConstants.mentorships}/book',
      data: _bookingBody(mentorshipId, scheduledAt, notes),
    );
  }

  /// Paid session, paid from wallet main balance (POST /mentorships/book-wallet).
  /// The server checks the balance, deducts the fee and holds it in escrow.
  /// Returns the fresh wallet balances when the server sends them.
  Future<WalletSummary?> bookWithWallet({
    required String mentorshipId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.mentorshipBookWallet,
      data: _bookingBody(mentorshipId, scheduledAt, notes),
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['wallet'] is Map<String, dynamic>) {
      return WalletSummary.fromJson(data['wallet'] as Map<String, dynamic>);
    }
    return null;
  }

  /// Paid session via Razorpay, step 1 (POST /mentorships/create-order).
  /// The server creates a pending booking + Razorpay order for the real price.
  Future<PaymentOrder> createBookingOrder({
    required String mentorshipId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.mentorshipCreateOrder,
      data: _bookingBody(mentorshipId, scheduledAt, notes),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final order = PaymentOrder.fromJson(data);
      if (order.isValid && order.bookingId.isNotEmpty) return order;
    }
    throw const AppValidationException(
      'Could not start the payment. Please try again.',
    );
  }

  /// Paid session via Razorpay, step 3 (POST /mentorships/verify-payment).
  /// The server verifies the signature and confirms the booking.
  Future<void> verifyBookingPayment({
    required String bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    await _apiClient.post(
      ApiConstants.mentorshipVerifyPayment,
      data: {
        'booking_id': bookingId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
  }

  /// Sessions booked by the signed-in user (GET /mentorships/bookings/my),
  /// newest first. Throws on failure (never shown as "no sessions").
  Future<List<BookingItem>> getMyBookings() async {
    final response = await _apiClient.get(ApiConstants.mentorshipMyBookings);
    final bookings = readListResponse(response.data)
        .map(BookingItem.fromJson)
        .toList();
    bookings.sort((a, b) {
      final at = a.scheduledAt, bt = b.scheduledAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return bookings;
  }

  /// Rate a completed session (POST /mentorships/bookings/:id/review,
  /// body `{rating, review}`). The backend accepts it only from the user
  /// who booked and only once the session is `completed`; its reason is
  /// shown otherwise (AppValidationException).
  Future<void> submitBookingReview({
    required String bookingId,
    required int rating,
    String review = '',
  }) async {
    if (bookingId.trim().isEmpty) {
      throw const AppValidationException(
        'This session cannot be rated. Please refresh and try again.',
      );
    }
    if (rating < 1 || rating > 5) {
      throw const AppValidationException('Please choose 1 to 5 stars.');
    }
    await _apiClient.post(
      '${ApiConstants.mentorshipBookings}/$bookingId/review',
      data: {'rating': rating, 'review': review.trim()},
    );
  }
}

/// The signed-in user's booked mentorship sessions. Loaded fresh each time
/// the My Sessions screen opens (so a just-booked session shows), rebuilt on
/// logout / account switch, and no request without a session.
final myBookingsProvider = FutureProvider.autoDispose<List<BookingItem>>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <BookingItem>[];
  }
  return ref.watch(expertRepositoryProvider).getMyBookings();
});
