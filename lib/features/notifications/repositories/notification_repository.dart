import '../../../core/network/api_client.dart';
import '../models/notification_item.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  static final List<NotificationItem> _fallbackNotifications = [
    NotificationItem(
      id: 'notif_1',
      type: 'profile_view',
      title: '3 Recruiters Viewed Your Profile',
      message: 'HR Managers from Reliance Retail and Swiggy visited your digital CV today.',
      avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=150',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      targetRoute: '/profile',
    ),
    NotificationItem(
      id: 'notif_2',
      type: 'connection',
      title: 'Connection Request Accepted',
      message: 'Amit Patel accepted your connection request on KaamMilega.',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=150',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      targetRoute: '/network',
    ),
    NotificationItem(
      id: 'notif_3',
      type: 'job_alert',
      title: 'New Jobs Match Your Profile',
      message: '5 new Senior Delivery Lead & Warehouse Supervisor jobs posted in Mumbai.',
      avatarUrl: '',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      targetRoute: '/jobs',
    ),
    NotificationItem(
      id: 'notif_4',
      type: 'application',
      title: 'Application Status Updated',
      message: 'Your application for Logistics Manager was shortlisted by HR.',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=150',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      targetRoute: '/applications',
    ),
  ];

  Future<List<NotificationItem>> getNotifications() async {
    try {
      final res = await _apiClient.get('/notifications');
      if (res.data != null && res.data['notifications'] is List) {
        final list = (res.data['notifications'] as List)
            .map(
              (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return List.from(_fallbackNotifications);
  }
}
