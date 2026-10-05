import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../models/notification_item.dart';

/// In-app notifications (km-backend `/api/notifications`, signed-in only).
///
/// Errors are thrown as [AppException]s, never turned into an empty list.
class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  static const int pageSize = 20;

  /// GET /notifications?category=&unread_only=&limit=&offset=
  /// -> {notifications: [...], total, limit, offset}, newest first.
  Future<NotificationsPage> getNotificationsPage({
    String category = NotificationCategory.all,
    bool unreadOnly = false,
    int offset = 0,
    int limit = pageSize,
  }) async {
    final res = await _apiClient.get(
      ApiConstants.notifications,
      queryParameters: {
        if (category != NotificationCategory.all) 'category': category,
        if (unreadOnly) 'unread_only': true,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = res.data;
    if (data is! Map || data['notifications'] is! List) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    final items = (data['notifications'] as List)
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = data['total'];
    return NotificationsPage(
      items: items,
      total: total is num ? total.toInt() : items.length + offset,
    );
  }

  /// GET /notifications/unread-count -> {unread_count}
  Future<int> getUnreadCount() async {
    final res = await _apiClient.get(ApiConstants.notificationsUnreadCount);
    final data = res.data;
    final count = data is Map ? data['unread_count'] : null;
    if (count is! num) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    return count.toInt();
  }

  /// GET /notifications?category=messages&unread_only=true: the unread chat
  /// message notifications (newest first, at most [limit]).
  Future<List<NotificationItem>> getUnreadMessageNotifications({
    int limit = 100,
  }) async {
    final page = await _unreadMessages(limit: limit);
    return page.items;
  }

  /// How many chat message notifications are unread (the server's total).
  Future<int> getUnreadMessageCount() async =>
      (await _unreadMessages(limit: 1)).total;

  Future<NotificationsPage> _unreadMessages({required int limit}) async {
    final res = await _apiClient.get(
      ApiConstants.notifications,
      queryParameters: {
        'category': NotificationCategory.messages,
        'unread_only': true,
        'limit': limit,
        'offset': 0,
      },
    );
    final data = res.data;
    if (data is! Map ||
        data['notifications'] is! List ||
        data['total'] is! num) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    return NotificationsPage(
      items: (data['notifications'] as List)
          .whereType<Map>()
          .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: (data['total'] as num).toInt(),
    );
  }

  /// PUT /notifications/:id/read
  Future<void> markAsRead(String id) =>
      _apiClient.put(ApiConstants.notificationRead(id));

  /// PUT /notifications/read-all
  Future<void> markAllAsRead() =>
      _apiClient.put(ApiConstants.notificationsReadAll);

  /// DELETE /notifications/:id
  Future<void> delete(String id) =>
      _apiClient.delete(ApiConstants.notification(id));
}
