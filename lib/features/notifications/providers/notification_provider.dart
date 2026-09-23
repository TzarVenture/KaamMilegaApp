import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationNotifier extends AsyncNotifier<List<NotificationItem>> {
  bool _isEndpointUnavailable = false;

  @override
  Future<List<NotificationItem>> build() async {
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      _isEndpointUnavailable = false;
      return const [];
    }

    // If endpoint was already recognized as 404/under development,
    // do not trigger repeated network calls on routine rebuilds/tab switches.
    // Manual pull-to-refresh / retry will probe the endpoint again.
    if (_isEndpointUnavailable) {
      throw const AppNotFoundException(
        'Notifications are coming soon.',
      );
    }

    try {
      final items = await ref
          .read(notificationRepositoryProvider)
          .getNotifications();
      _isEndpointUnavailable = false;
      return items;
    } on AppNotFoundException catch (_) {
      _isEndpointUnavailable = true;
      rethrow;
    }
  }

  /// Explicit manual refresh / retry initiated by user
  Future<void> refresh() async {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated) {
      _isEndpointUnavailable = false;
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    _isEndpointUnavailable = false; // Reset to probe live API
    state = await AsyncValue.guard(() async {
      try {
        final items = await ref
            .read(notificationRepositoryProvider)
            .getNotifications();
        _isEndpointUnavailable = false;
        return items;
      } on AppNotFoundException catch (_) {
        _isEndpointUnavailable = true;
        rethrow;
      }
    });
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
