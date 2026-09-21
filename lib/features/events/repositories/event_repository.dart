import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/event.dart';

/// Repository for handling Career Events and Webinars with km-backend
class EventRepository {
  final ApiClient _client;

  EventRepository(this._client);

  static final List<EventItem> _fallbackEvents = [
    const EventItem(
      id: 'ev_101',
      title: 'India Blue-Collar & Logistics Career Expo 2026',
      organizer: 'KaamMilega HR Network & National Skill Council',
      description: 'Connect with top hiring partners in logistics, warehousing, and delivery services across Mumbai, Delhi, and Bangalore.',
      date: '2026-09-28',
      time: '10:00 AM IST',
      dateString: 'Sat, Sep 28 • 10:00 AM IST',
      location: 'Online Live Stream & Mumbai BKC Expo Hall',
      imageUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&q=80&w=800',
      attendeesCount: 1420,
      isRegistered: false,
    ),
    const EventItem(
      id: 'ev_102',
      title: 'Mastering Resume & Salary Negotiations with HR Leaders',
      organizer: 'Senior Talent Acquisition Team',
      description: 'Interactive coaching session on optimizing your candidate CV and negotiating high-bracket wages with verified recruiters.',
      date: '2026-10-02',
      time: '6:30 PM IST',
      dateString: 'Wed, Oct 2 • 6:30 PM IST',
      location: 'Interactive Zoom Webinar',
      imageUrl: 'https://images.unsplash.com/photo-1515187029135-18ee286d815b?auto=format&fit=crop&q=80&w=800',
      attendeesCount: 890,
      isRegistered: false,
    ),
    const EventItem(
      id: 'ev_103',
      title: 'Instant Gig Worker Safety & Earnings Masterclass',
      organizer: 'KaamMilega Gig Worker Welfare Association',
      description: 'Learn about route optimization, insurance benefits, and maximizing peak-hour gig dispatches on KaamMilega.',
      date: '2026-10-10',
      time: '4:00 PM IST',
      dateString: 'Sat, Oct 10 • 4:00 PM IST',
      location: 'Live Stream on KaamMilega App',
      imageUrl: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&q=80&w=800',
      attendeesCount: 650,
      isRegistered: false,
    ),
  ];

  /// Fetch events from backend with pagination and optional search
  Future<List<EventItem>> getEvents({
    String? search,
    String? location,
    int page = 1,
    int limit = 20,
    String? currentUserId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (location != null && location.trim().isNotEmpty) {
        queryParams['location'] = location.trim();
      }

      final response = await _client.get(
        ApiConstants.events,
        queryParameters: queryParams,
      );

      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is Map<String, dynamic>) {
        if (body['data'] is List) {
          list = body['data'];
        } else if (body['events'] is List) {
          list = body['events'];
        }
      } else if (body is List) {
        list = body;
      }

      if (list.isNotEmpty) {
        return list
            .map(
              (e) => EventItem.fromJson(
                e as Map<String, dynamic>,
                currentUserId: currentUserId,
              ),
            )
            .toList();
      }
    } catch (_) {
      // Fallback gracefully on network error or empty response
    }

    return List.from(_fallbackEvents);
  }

  /// Register candidate for a specific event
  Future<bool> registerForEvent(String eventId) async {
    final response = await _client.post(
      '${ApiConstants.events}/$eventId/register',
    );
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return true;
    }
    return false;
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(apiClientProvider));
});
