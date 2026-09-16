import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    return ref.read(notificationRepositoryProvider).getNotifications();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).getNotifications(),
    );
  }

  void markAsRead(String id) {
    final currentList = state.value ?? [];
    state = AsyncValue.data(
      currentList.map((item) {
        if (item.id == id) return item.copyWith(isRead: true);
        return item;
      }).toList(),
    );
  }

  void markAllAsRead() {
    final currentList = state.value ?? [];
    state = AsyncValue.data(
      currentList.map((item) => item.copyWith(isRead: true)).toList(),
    );
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationNotifier, List<NotificationItem>>(
      NotificationNotifier.new,
    );

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final asyncNotifs = ref.watch(notificationsProvider);
  return asyncNotifs.maybeWhen(
    data: (items) => items.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
});
