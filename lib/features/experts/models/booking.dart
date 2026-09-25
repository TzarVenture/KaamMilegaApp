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
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    final amount = json['amount'];
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
    );
  }

  bool get isFree => amount <= 0;

  /// The meeting link is shown only for a confirmed session that has one.
  bool get canJoin => status == 'confirmed' && meetingLink.isNotEmpty;
}
