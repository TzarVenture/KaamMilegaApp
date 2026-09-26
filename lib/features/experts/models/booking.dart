import '../../../core/constants/api_constants.dart';

/// A mentorship session booked by the signed-in user
/// (km-backend `Booking` from GET /mentorships/bookings/my, including the
/// fields the backend adds for display: mentorship title and expert info).
class BookingItem {
  final String id;
  final String mentorshipId;
  final String expertId;
  final DateTime? scheduledAt;

  /// "pending", "confirmed", "cancelled" or "completed".
  final String status;
  final double amount;

  /// "pending", "paid" or "refunded".
  final String paymentStatus;

  /// "wallet" or "razorpay" (empty for free sessions).
  final String paymentMethod;
  final String meetingLink;
  final String notes;
  final String mentorshipTitle;
  final String expertName;
  final String expertHeadline;
  final String expertImage;

  /// The user's rating of the session (1–5); 0 when not rated yet.
  final double rating;

  /// The user's written review (may be empty even when rated).
  final String review;

  const BookingItem({
    required this.id,
    required this.mentorshipId,
    required this.expertId,
    this.scheduledAt,
    this.status = '',
    this.amount = 0,
    this.paymentStatus = '',
    this.paymentMethod = '',
    this.meetingLink = '',
    this.notes = '',
    this.mentorshipTitle = '',
    this.expertName = '',
    this.expertHeadline = '',
    this.expertImage = '',
    this.rating = 0,
    this.review = '',
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    final amount = json['amount'];
    final rating = json['rating'];
    return BookingItem(
      id: str('id'),
      mentorshipId: str('mentorship_id'),
      expertId: str('expert_id'),
      scheduledAt: DateTime.tryParse(str('scheduled_at'))?.toLocal(),
      status: str('status').toLowerCase(),
      amount: amount is num ? amount.toDouble() : 0,
      paymentStatus: str('payment_status').toLowerCase(),
      paymentMethod: str('payment_method').toLowerCase(),
      meetingLink: str('meeting_link'),
      notes: str('notes'),
      mentorshipTitle: str('mentorship_title'),
      expertName: str('expert_name'),
      expertHeadline: str('expert_headline'),
      expertImage: ApiConstants.resolveImageUrl(str('expert_image')),
      rating: rating is num ? rating.toDouble() : 0,
      review: str('review'),
    );
  }

  bool get isFree => amount <= 0;

  /// The meeting link is shown only for a confirmed session that has one.
  bool get canJoin => status == 'confirmed' && meetingLink.isNotEmpty;

  bool get isReviewed => rating > 0;

  /// The backend accepts a review only for the user's completed sessions
  /// (POST /mentorships/bookings/:id/review).
  bool get canReview => status == 'completed' && !isReviewed && id.isNotEmpty;
}
