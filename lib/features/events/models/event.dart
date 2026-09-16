class EventItem {
  final String id;
  final String title;
  final String organizer;
  final String dateString;
  final String location;
  final String imageUrl;
  final int attendeesCount;
  final bool isRegistered;

  const EventItem({
    required this.id,
    required this.title,
    required this.organizer,
    required this.dateString,
    required this.location,
    this.imageUrl = '',
    this.attendeesCount = 0,
    this.isRegistered = false,
  });

  EventItem copyWith({
    String? id,
    String? title,
    String? organizer,
    String? dateString,
    String? location,
    String? imageUrl,
    int? attendeesCount,
    bool? isRegistered,
  }) {
    return EventItem(
      id: id ?? this.id,
      title: title ?? this.title,
      organizer: organizer ?? this.organizer,
      dateString: dateString ?? this.dateString,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      attendeesCount: attendeesCount ?? this.attendeesCount,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Webinar Event',
      organizer: json['organizer']?.toString() ?? 'KaamMilega Experts',
      dateString: json['date_string']?.toString() ?? 'Upcoming',
      location: json['location']?.toString() ?? 'Online Webinar',
      imageUrl: json['image_url']?.toString() ?? '',
      attendeesCount: (json['attendees_count'] as num?)?.toInt() ?? 0,
      isRegistered: json['is_registered'] == true,
    );
  }
}
