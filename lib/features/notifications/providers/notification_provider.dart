import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return const [];
    }
    return ref.read(notificationRepositoryProvider).getNotifications();
  }

  Future<void> refresh() async {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated) {
      state = const AsyncValue.data([]);
      return;
    }
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
  final isAuthenticated = ref.watch(
    authProvider.select((s) => s.isAuthenticated),
  );
  if (!isAuthenticated) return 0;

  final asyncNotifs = ref.watch(notificationsProvider);
  return asyncNotifs.maybeWhen(
    data: (items) => items.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
});
