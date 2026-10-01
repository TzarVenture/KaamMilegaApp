import '../../../core/constants/api_constants.dart';

/// A person attending an event (GET /events/:id/attendees). Only public
/// profile fields are read; the ticket number and payment type the server
/// also sends are not used.
class EventParticipant {
  final String id;
  final String name;
  final String headline;
  final String profileImage;
  final String city;

  const EventParticipant({
    required this.id,
    required this.name,
    this.headline = '',
    this.profileImage = '',
    this.city = '',
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    return EventParticipant(
      id: str('id'),
      name: str('name'),
      headline: str('headline'),
      profileImage: ApiConstants.resolveImageUrl(str('profile_image')),
      city: str('city'),
    );
  }

  String get displayName => name.isNotEmpty ? name : 'KaamMilega member';

  /// Headline, else city, else nothing.
  String get subtitle => headline.isNotEmpty ? headline : city;
}

/// The attendee list with the server's total.
class EventAttendees {
  final int total;
  final List<EventParticipant> people;

  const EventAttendees({required this.total, required this.people});

  factory EventAttendees.fromJson(Map<String, dynamic> json) {
    final raw = json['attendees'];
    final people = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (e) => EventParticipant.fromJson(Map<String, dynamic>.from(e)),
              )
              .where((p) => p.id.isNotEmpty)
              .toList()
        : <EventParticipant>[];
    final total = json['total_joined'];
    return EventAttendees(
      total: total is num ? total.toInt() : people.length,
      people: people,
    );
  }
}
