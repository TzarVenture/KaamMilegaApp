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
  });

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

    final bool registered = json['is_registered'] == true ||
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
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      participants: participantsList,
      attendeesCount: count,
      isRegistered: registered,
      createdAt: parsedCreatedAt,
    );
  }
}
