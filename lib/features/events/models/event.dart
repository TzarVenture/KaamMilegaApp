import '../../../core/constants/api_constants.dart';

class EventItem {
  final String id;
  final String title;
  final String organizer;
  final String description;
  final String date;
  final String time;
  final String dateString;
  final String location;
  final String imageUrl;
  final List<String> participants;
  final int attendeesCount;
  final bool isRegistered;
  final DateTime? createdAt;

  /// Paid ticketing (backend F63). [price] is in rupees; 0 for free events.
  final bool isPaid;
  final double price;
  final String currency;
  final String category;

  /// Maximum seats; 0 means unlimited.
  final int capacity;

  /// Seats left when [capacity] is set (the backend omits 0).
  final int availableSeats;

  const EventItem({
    required this.id,
    required this.title,
    required this.organizer,
    this.description = '',
    this.date = '',
    this.time = '',
    required this.dateString,
    required this.location,
    this.imageUrl = '',
    this.participants = const [],
    this.attendeesCount = 0,
    this.isRegistered = false,
    this.createdAt,
    this.isPaid = false,
    this.price = 0,
    this.currency = 'INR',
    this.category = '',
    this.capacity = 0,
    this.availableSeats = 0,
  });

  /// True when a ticket must be bought (Razorpay or wallet) instead of the
  /// free registration; the backend uses the same rule.
  bool get requiresPayment => isPaid && price > 0;

  /// Same rule as the backend: no seats left, or every seat taken.
  bool get isSoldOut =>
      capacity > 0 && (availableSeats <= 0 || participants.length >= capacity);

  /// Seats still open, or null for events without a seat limit.
  int? get seatsLeft {
    if (capacity <= 0) return null;
    return availableSeats < 0 ? 0 : availableSeats;
  }

  /// "Free" or the ticket price, e.g. "₹499" / "₹99.50".
  String get priceLabel {
    if (!requiresPayment) return 'Free';
    final whole = price == price.roundToDouble();
    return '₹${price.toStringAsFixed(whole ? 0 : 2)}';
  }

  EventItem copyWith({
    String? id,
    String? title,
    String? organizer,
    String? description,
    String? date,
    String? time,
    String? dateString,
    String? location,
    String? imageUrl,
    List<String>? participants,
    int? attendeesCount,
    bool? isRegistered,
    DateTime? createdAt,
    int? availableSeats,
  }) {
    return EventItem(
      id: id ?? this.id,
      title: title ?? this.title,
      organizer: organizer ?? this.organizer,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      dateString: dateString ?? this.dateString,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      participants: participants ?? this.participants,
      attendeesCount: attendeesCount ?? this.attendeesCount,
      isRegistered: isRegistered ?? this.isRegistered,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid,
      price: price,
      currency: currency,
      category: category,
      capacity: capacity,
      availableSeats: availableSeats ?? this.availableSeats,
    );
  }

  factory EventItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final rawParticipants = json['participants'];
    final List<String> participantsList = [];
    if (rawParticipants is List) {
      for (final p in rawParticipants) {
        if (p != null) {
          participantsList.add(p.toString());
        }
      }
    }

    final rawDate = json['date']?.toString() ?? '';
    final rawTime = json['time']?.toString() ?? '';
    String derivedDateString = json['date_string']?.toString() ?? '';
    if (derivedDateString.isEmpty) {
      if (rawDate.isNotEmpty && rawTime.isNotEmpty) {
        derivedDateString = '$rawDate • $rawTime';
      } else if (rawDate.isNotEmpty) {
        derivedDateString = rawDate;
      } else {
        derivedDateString = 'Upcoming Event';
      }
    }

    final bool registered =
        json['is_registered'] == true ||
        (currentUserId != null &&
            currentUserId.isNotEmpty &&
            participantsList.contains(currentUserId));

    final int count = participantsList.isNotEmpty
        ? participantsList.length
        : (json['attendees_count'] as num?)?.toInt() ?? 0;

    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    }

    return EventItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Webinar & Career Event',
      organizer: json['organizer']?.toString() ?? 'KaamMilega Network',
      description: json['description']?.toString() ?? '',
      date: rawDate,
      time: rawTime,
      dateString: derivedDateString,
      location: json['location']?.toString() ?? 'Online Webinar',
      imageUrl: ApiConstants.resolveImageUrl(
        json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      ),
      participants: participantsList,
      attendeesCount: count,
      isRegistered: registered,
      createdAt: parsedCreatedAt,
      isPaid: json['is_paid'] == true,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString().isNotEmpty == true
          ? json['currency'].toString()
          : 'INR',
      category: json['category']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      availableSeats: (json['available_seats'] as num?)?.toInt() ?? 0,
    );
  }
}
