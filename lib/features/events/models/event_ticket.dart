/// An event ticket issued by the backend (km-backend `event.EventTicket`).
///
/// Free registrations, Razorpay purchases and wallet purchases all create
/// one; [paymentMethod] says which.
class EventTicket {
  final String id;
  final String ticketNumber;
  final String eventId;
  final String attendeeName;
  final String attendeeEmail;
  final String attendeePhone;
  final double amount;

  /// free / paid / refunded
  final String paymentStatus;

  /// free / razorpay / wallet
  final String paymentMethod;
  final String razorpayPaymentId;

  /// confirmed / cancelled
  final String status;

  /// Text encoded in the entry QR code.
  final String qrCodeData;
  final String eventTitle;
  final String eventDate;
  final String eventTime;
  final String eventLocation;
  final DateTime? createdAt;

  const EventTicket({
    required this.id,
    required this.ticketNumber,
    required this.eventId,
    this.attendeeName = '',
    this.attendeeEmail = '',
    this.attendeePhone = '',
    this.amount = 0,
    this.paymentStatus = '',
    this.paymentMethod = '',
    this.razorpayPaymentId = '',
    this.status = '',
    this.qrCodeData = '',
    this.eventTitle = '',
    this.eventDate = '',
    this.eventTime = '',
    this.eventLocation = '',
    this.createdAt,
  });

  factory EventTicket.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString() ?? '';
    return EventTicket(
      id: str('id').isNotEmpty ? str('id') : str('_id'),
      ticketNumber: str('ticket_number'),
      eventId: str('event_id'),
      attendeeName: str('attendee_name'),
      attendeeEmail: str('attendee_email'),
      attendeePhone: str('attendee_phone'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: str('payment_status'),
      paymentMethod: str('payment_method'),
      razorpayPaymentId: str('razorpay_payment_id'),
      status: str('status'),
      qrCodeData: str('qr_code_data'),
      eventTitle: str('event_title'),
      eventDate: str('event_date'),
      eventTime: str('event_time'),
      eventLocation: str('event_location'),
      createdAt: DateTime.tryParse(str('created_at')),
    );
  }

  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isRefunded => paymentStatus == 'refunded';

  String get statusLabel {
    if (isRefunded) return 'Refunded';
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  /// "Free", "₹499 · Wallet", "₹499 · Paid online".
  String get paymentLabel {
    if (paymentMethod == 'free' || amount <= 0) return 'Free';
    final whole = amount == amount.roundToDouble();
    final price = '₹${amount.toStringAsFixed(whole ? 0 : 2)}';
    switch (paymentMethod) {
      case 'wallet':
        return '$price · Wallet';
      case 'razorpay':
        return '$price · Paid online';
      default:
        return price;
    }
  }

  /// "12 Oct 2026 · 5:00 PM" style line from the event's own strings.
  String get whenLabel {
    if (eventDate.isNotEmpty && eventTime.isNotEmpty) {
      return '$eventDate · $eventTime';
    }
    return eventDate.isNotEmpty ? eventDate : eventTime;
  }
}

/// Attendee details sent with a paid ticket order (name and email required).
class EventAttendee {
  final String name;
  final String email;
  final String phone;

  const EventAttendee({
    required this.name,
    required this.email,
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
    'attendee_name': name.trim(),
    'attendee_email': email.trim(),
    if (phone.trim().isNotEmpty) 'attendee_phone': phone.trim(),
  };
}
