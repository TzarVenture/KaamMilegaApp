import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/event.dart';

/// Repository for handling Career Events and Webinars with km-backend
class EventRepository {
  final ApiClient _client;

  EventRepository(this._client);

  /// Fetch events from backend with pagination and optional search
  Future<List<EventItem>> getEvents({
    String? search,
    String? location,
    int page = 1,
    int limit = 20,
    String? currentUserId,
  }) async {
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
    return [];
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
