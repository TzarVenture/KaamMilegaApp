import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/response_list.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/models/wallet_summary.dart';
import '../models/booking.dart';
import '../models/expert_offering.dart';
import '../models/expert_plan.dart';
import '../models/expert_profile.dart';
import '../models/expert_review.dart';

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

  /// An Expert's ratings and reviews from mentees of completed sessions
  /// (GET /mentorships/expert/:id/reviews, public): average, count per star
  /// and the reviews, newest first. Throws on failure, so the page shows an
  /// error, never "no reviews".
  Future<ExpertReviews> getExpertReviews(String expertId) async {
    final response = await _apiClient.get(
      ApiConstants.mentorshipExpertReviews(expertId),
    );
    final data = response.data;
    if (data is! Map) {
      throw const AppServerException('Unexpected reviews response.');
    }
    return ExpertReviews.fromJson(Map<String, dynamic>.from(data));
  }

  // --- Expert dashboard (user with the "expert" role) ---

  /// Sessions other users booked with me (GET /mentorships/bookings/expert),
  /// soonest first; each carries the mentee's name.
  Future<List<BookingItem>> getExpertBookings() async {
    final response = await _apiClient.get(
      ApiConstants.mentorshipExpertBookings,
    );
    final bookings = readListResponse(response.data)
        .map(BookingItem.fromJson)
        .where((b) => b.id.isNotEmpty)
        .toList();
    bookings.sort((a, b) {
      final at = a.scheduledAt, bt = b.scheduledAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
    return bookings;
  }

  /// Confirm, cancel (refunds a paid mentee) or complete (releases the
  /// held payment to my earnings) a booking
  /// (PATCH /mentorships/bookings/:id/status, body `{status}`).
  Future<void> updateBookingStatus(String bookingId, String status) async {
    const allowed = {'confirmed', 'cancelled', 'completed'};
    if (bookingId.trim().isEmpty || !allowed.contains(status)) {
      throw const AppValidationException(
        'This session cannot be updated. Please refresh and try again.',
      );
    }
    await _apiClient.patch(
      '${ApiConstants.mentorshipBookings}/$bookingId/status',
      data: {'status': status},
    );
  }

  /// Sets the video-call link for a booking
  /// (PATCH /mentorships/bookings/:id/meeting-link).
  Future<void> updateMeetingLink(String bookingId, String link) async {
    final url = normalizeMeetingLink(link);
    if (bookingId.trim().isEmpty || url == null) {
      throw const AppValidationException(
        'Please enter a valid meeting link (for example a Google Meet or '
        'Zoom link).',
      );
    }
    await _apiClient.patch(
      '${ApiConstants.mentorshipBookings}/$bookingId/meeting-link',
      data: {'meeting_link': url},
    );
  }

  /// An http(s) link with a host, "https://" added when missing; null when
  /// it is not a usable link.
  static String? normalizeMeetingLink(String input) {
    var value = input.trim();
    if (value.isEmpty || value.contains(' ')) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.host.contains('.')) return null;
    return value;
  }

  /// My session offerings (GET /mentorships/expert/my).
  Future<List<ExpertOffering>> getMyOfferings() async {
    final response = await _apiClient.get(ApiConstants.mentorshipExpertMy);
    return readListResponse(response.data)
        .map(ExpertOffering.fromJson)
        .where((o) => o.id.isNotEmpty)
        .toList();
  }

  /// Creates an offering (POST /mentorships) or, with [id], updates it
  /// (PATCH /mentorships/:id; the server replaces every field).
  Future<void> saveOffering(ExpertOfferingDraft draft, {String? id}) async {
    final problem = draft.problem;
    if (problem != null) throw AppValidationException(problem);
    if (id == null) {
      await _apiClient.post(ApiConstants.mentorships, data: draft.toJson());
    } else {
      await _apiClient.patch(
        '${ApiConstants.mentorships}/$id',
        data: draft.toJson(),
      );
    }
  }

  /// Deletes an offering (DELETE /mentorships/:id).
  Future<void> deleteOffering(String id) async {
    if (id.trim().isEmpty) {
      throw const AppValidationException('This session cannot be deleted.');
    }
    await _apiClient.delete('${ApiConstants.mentorships}/$id');
  }

  /// My weekly hours (GET /mentorships/availability).
  Future<List<WeeklyHours>> getMyAvailability() async {
    final response = await _apiClient.get(ApiConstants.mentorshipAvailability);
    return _hours(response.data);
  }

  /// An Expert's weekly hours for booking
  /// (GET /mentorships/expert/:id/availability, public).
  Future<List<WeeklyHours>> getExpertAvailability(String expertId) async {
    final response = await _apiClient.get(
      ApiConstants.mentorshipExpertAvailability(expertId),
    );
    return _hours(response.data);
  }

  /// Replaces all my weekly hours (PUT /mentorships/availability, a JSON
  /// list of `{day_of_week, start_time, end_time}`).
  Future<void> saveAvailability(List<WeeklyHours> hours) async {
    if (hours.isEmpty) {
      throw const AppValidationException('Please turn on at least one day.');
    }
    if (hours.any((h) => !h.isValid)) {
      throw const AppValidationException('Each day must end after it starts.');
    }
    await _apiClient.put(
      ApiConstants.mentorshipAvailability,
      data: hours.map((h) => h.toJson()).toList(),
    );
  }

  static List<WeeklyHours> _hours(dynamic data) {
    final list = readListResponse(data)
        .map(WeeklyHours.fromJson)
        .whereType<WeeklyHours>()
        .toList();
    list.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return list;
  }

  // --- Pro Expert plans (/subscriptions/expert) ---

  /// Plans with their perks (GET /subscriptions/expert/plans, public).
  Future<List<ExpertPlan>> getExpertPlans() async {
    final response = await _apiClient.get(ApiConstants.expertPlans);
    return readListResponse(
      response.data,
      keys: const ['plans', 'data'],
    ).map(ExpertPlan.fromJson).where((p) => p.isValid).toList();
  }

  /// The signed-in user's plan (GET /subscriptions/expert/my).
  Future<ExpertSubscriptionStatus> getMyExpertSubscription() async {
    final response = await _apiClient.get(ApiConstants.expertSubscriptionMy);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ExpertSubscriptionStatus.fromJson(data);
    }
    throw const AppValidationException(
      'Could not read your plan status. Please try again.',
    );
  }

  /// Razorpay order for a plan (POST /subscriptions/expert/create-order).
  Future<PaymentOrder> createExpertPlanOrder(String planType) async {
    final response = await _apiClient.post(
      ApiConstants.expertSubscriptionCreateOrder,
      data: {'plan_type': planType},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final order = PaymentOrder.fromJson(data);
      if (order.isValid) return order;
    }
    throw const AppValidationException(
      'Could not start the payment. Please try again.',
    );
  }

  /// The server checks the Razorpay signature and activates the plan
  /// (POST /subscriptions/expert/verify-payment). Returns its message.
  Future<String> verifyExpertPlanPayment({
    required String planType,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.expertSubscriptionVerify,
      data: {
        'plan_type': planType,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    return _activatedMessage(response.data);
  }

  /// Pays for a plan from the wallet main balance
  /// (POST /subscriptions/expert/wallet-checkout). Returns its message.
  Future<String> buyExpertPlanWithWallet(String planType) async {
    final response = await _apiClient.post(
      ApiConstants.expertSubscriptionWalletCheckout,
      data: {'plan_type': planType},
    );
    return _activatedMessage(response.data);
  }

  /// Reads `{message, subscription}`; a reply without the subscription is
  /// an error, not a silent success.
  static String _activatedMessage(dynamic data) {
    if (data is Map<String, dynamic> && data['subscription'] is Map) {
      return data['message']?.toString().trim() ?? '';
    }
    throw const AppValidationException(
      'Unexpected response from server. Please check your plan status.',
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

/// An Expert's ratings and reviews (GET /mentorships/expert/:id/reviews,
/// public). Reloaded each time the Expert's page opens.
final expertReviewsProvider = FutureProvider.autoDispose
    .family<ExpertReviews, String>((ref, expertId) {
      if (expertId.trim().isEmpty) return ExpertReviews.empty;
      return ref.watch(expertRepositoryProvider).getExpertReviews(expertId);
    });

/// An Expert's published weekly hours, for the booking screen
/// (GET /mentorships/expert/:id/availability, public). Empty when the
/// Expert has not set any.
final expertAvailabilityProvider = FutureProvider.autoDispose
    .family<List<WeeklyHours>, String>((ref, expertId) {
      if (expertId.trim().isEmpty) return const <WeeklyHours>[];
      return ref
          .watch(expertRepositoryProvider)
          .getExpertAvailability(expertId);
    });
