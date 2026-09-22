import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_item.dart';

/// Repository for handling in-app notifications
class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  /// Fetch notifications from backend API.
  /// Throws [AppException] (e.g. [AppNotFoundException] if endpoint is not yet mounted).
  Future<List<NotificationItem>> getNotifications() async {
    final res = await _apiClient.get(ApiConstants.notifications);
    if (res.data != null &&
        res.data is Map &&
        res.data['notifications'] is List) {
      return (res.data['notifications'] as List)
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    if (res.data is List) {
      return (res.data as List)
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }
}
