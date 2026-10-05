import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_socket_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

/// Selected tab on the Notifications screen (a backend category).
class NotificationCategoryNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(sessionUserIdProvider); // back to "All" for the next account
    return NotificationCategory.all;
  }

  void select(String category) => state = category;
}

final notificationCategoryProvider =
    NotifierProvider<NotificationCategoryNotifier, String>(
      NotificationCategoryNotifier.new,
    );

/// "Unread only" switch on the Notifications screen (`?unread_only=true`).
class NotificationUnreadOnlyNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(sessionUserIdProvider);
    return false;
  }

  void set(bool value) => state = value;
}

final notificationUnreadOnlyProvider =
    NotifierProvider<NotificationUnreadOnlyNotifier, bool>(
      NotificationUnreadOnlyNotifier.new,
    );

/// Loaded notifications of the selected category.
///
/// Every kind is listed, chat messages too (as on the website).
class NotificationFeed {
  const NotificationFeed({
    this.items = const [],
    this.total = 0,
    this.loaded = 0,
    this.isLoadingMore = false,
  });

  final List<NotificationItem> items;

  /// All notifications of this category on the server.
  final int total;

  /// How many the server has sent so far (message ones included); the
  /// offset of the next page.
  final int loaded;
  final bool isLoadingMore;

  bool get hasMore => loaded < total;

  NotificationFeed copyWith({
    List<NotificationItem>? items,
    int? total,
    int? loaded,
    bool? isLoadingMore,
  }) {
    return NotificationFeed(
      items: items ?? this.items,
      total: total ?? this.total,
      loaded: loaded ?? this.loaded,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The Notifications list: first page from the server, more pages on
/// scroll, live updates from the socket, and read / delete saved on the
/// server (the screen updates at once and is restored if the server
/// refuses).
class NotificationNotifier extends AsyncNotifier<NotificationFeed> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  UnreadCountsNotifier get _unread => ref.read(unreadCountsProvider.notifier);

  @override
  Future<NotificationFeed> build() async {
    final userId = ref.watch(sessionUserIdProvider);
    final category = ref.watch(notificationCategoryProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    if (userId == null) return const NotificationFeed();

    ref.listen(notificationEventsProvider, (_, next) {
      final event = next.value;
      if (event != null) _onLive(event, category);
    });

    final page = await _repo.getNotificationsPage(
      category: category,
      unreadOnly: unreadOnly,
    );
    return NotificationFeed(
      items: page.items,
      total: page.total,
      loaded: page.items.length,
    );
  }

  /// Pull to refresh / Retry.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Shown by the screen's error state.
    }
  }

  /// Loads the next page. False when it failed (the list stays as it is).
  Future<bool> loadMore() async {
    final feed = state.value;
    if (feed == null || feed.isLoadingMore || !feed.hasMore) return true;
    final category = ref.read(notificationCategoryProvider);
    final unreadOnly = ref.read(notificationUnreadOnlyProvider);
    state = AsyncData(feed.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.getNotificationsPage(
        category: category,
        unreadOnly: unreadOnly,
        offset: feed.loaded,
      );
      if (!ref.mounted ||
          ref.read(notificationCategoryProvider) != category ||
          ref.read(notificationUnreadOnlyProvider) != unreadOnly) {
        return true;
      }
      final current = state.value ?? feed;
      final ids = current.items.map((n) => n.id).toSet();
      final loaded = current.loaded + page.items.length;
      state = AsyncData(
        NotificationFeed(
          items: [
            ...current.items,
            ...page.items.where((n) => !ids.contains(n.id)),
          ],
          // An empty page means the end, whatever the total said.
          total: page.items.isEmpty ? loaded : page.total,
          loaded: loaded,
        ),
      );
      return true;
    } catch (_) {
      if (ref.mounted) {
        final current = state.value ?? feed;
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
      return false;
    }
  }

  /// Marks one notification read. False when the server refused (the
  /// notification shows as unread again).
  Future<bool> markAsRead(String id) async {
    final feed = state.value;
    final item = feed?.items.where((n) => n.id == id).firstOrNull;
    final wasUnread = item != null && !item.isRead;
    if (wasUnread) {
      _replace(id, (n) => n.copyWith(isRead: true));
      _unread.adjust(-1);
    }
    try {
      await _repo.markAsRead(id);
      // Not in the loaded list: take the badge from the server.
      if (item == null) unawaited(_unread.refreshFromServer());
      return true;
    } catch (_) {
      if (wasUnread && ref.mounted) {
        _replace(id, (n) => n.copyWith(isRead: false));
        _unread.adjust(1);
      }
      return false;
    }
  }

  /// Marks every notification read. False when the server refused.
  Future<bool> markAllAsRead() async {
    final before = state.value;
    final countsBefore = ref.read(unreadCountsProvider);
    if (before != null) {
      state = AsyncData(
        before.copyWith(
          items: [for (final n in before.items) n.copyWith(isRead: true)],
        ),
      );
    }
    _unread.set(const UnreadCounts());
    try {
      await _repo.markAllAsRead();
      return true;
    } catch (_) {
      if (ref.mounted) {
        if (before != null) state = AsyncData(before);
        _unread.set(countsBefore);
      }
      return false;
    }
  }

  /// Deletes one notification. False when the server refused (it comes
  /// back in its place).
  Future<bool> delete(String id) async {
    final before = state.value;
    if (before == null) return false;
    final index = before.items.indexWhere((n) => n.id == id);
    if (index < 0) return false;
    final removed = before.items[index];
    state = AsyncData(
      before.copyWith(
        items: [...before.items]..removeAt(index),
        total: before.total > 0 ? before.total - 1 : 0,
        loaded: before.loaded > 0 ? before.loaded - 1 : 0,
      ),
    );
    if (!removed.isRead) _unread.adjust(-1);
    try {
      await _repo.delete(id);
      return true;
    } catch (_) {
      if (ref.mounted) {
        final current = state.value ?? before;
        final items = [...current.items];
        items.insert(index.clamp(0, items.length), removed);
        state = AsyncData(
          current.copyWith(
            items: items,
            total: current.total + 1,
            loaded: current.loaded + 1,
          ),
        );
        if (!removed.isRead) _unread.adjust(1);
      }
      return false;
    }
  }

  void _replace(String id, NotificationItem Function(NotificationItem) update) {
    final feed = state.value;
    if (feed == null) return;
    state = AsyncData(
      feed.copyWith(
        items: [for (final n in feed.items) n.id == id ? update(n) : n],
      ),
    );
  }

  void _onLive(NotificationEvent event, String category) {
    final feed = state.value;
    if (feed == null) return;
    switch (event.type) {
      case NotificationEventType.created:
        final n = event.notification!;
        if (category != NotificationCategory.all && n.category != category) {
          return;
        }
        final existed = feed.items.any((e) => e.id == n.id);
        state = AsyncData(
          feed.copyWith(
            items: [n, ...feed.items.where((e) => e.id != n.id)],
            total: existed ? feed.total : feed.total + 1,
            loaded: existed ? feed.loaded : feed.loaded + 1,
          ),
        );
      case NotificationEventType.read:
        _replace(event.notificationId, (n) => n.copyWith(isRead: true));
      case NotificationEventType.allRead:
        state = AsyncData(
          feed.copyWith(
            items: [for (final n in feed.items) n.copyWith(isRead: true)],
          ),
        );
      case NotificationEventType.deleted:
        if (!feed.items.any((e) => e.id == event.notificationId)) return;
        state = AsyncData(
          feed.copyWith(
            items: feed.items
                .where((e) => e.id != event.notificationId)
                .toList(),
            total: feed.total > 0 ? feed.total - 1 : 0,
            loaded: feed.loaded > 0 ? feed.loaded - 1 : 0,
          ),
        );
      case NotificationEventType.init:
        break;
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationFeed>(
      NotificationNotifier.new,
    );

/// Unread counts from the server: [all] notifications and the [messages]
/// ones among them (chat messages, shown on the Chats tab).
class UnreadCounts {
  const UnreadCounts({this.all = 0, this.messages = 0});

  final int all;
  final int messages;

  /// Everything except chat messages (the bell badge).
  int get others => all - messages < 0 ? 0 : all - messages;

  UnreadCounts copyWith({int? all, int? messages}) {
    final a = all ?? this.all;
    final m = messages ?? this.messages;
    return UnreadCounts(all: a < 0 ? 0 : a, messages: m < 0 ? 0 : m);
  }
}

/// GET /notifications/unread-count and the unread message notifications,
/// then kept up to date by the socket (every event carries the server's
/// total; message changes re-read the message count).
///
/// These are badges, so when a count cannot be loaded the last known value
/// stays (0 at start); the Notifications screen shows the real error.
class UnreadCountsNotifier extends Notifier<UnreadCounts> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  UnreadCounts build() {
    final userId = ref.watch(sessionUserIdProvider);
    if (userId == null) return const UnreadCounts();
    ref.listen(notificationEventsProvider, (_, next) {
      final event = next.value;
      if (event != null) _onLive(event);
    });
    Future.microtask(refreshFromServer);
    return const UnreadCounts();
  }

  void _onLive(NotificationEvent event) {
    final total = event.unreadCount;
    if (total != null) state = state.copyWith(all: total);
    switch (event.type) {
      case NotificationEventType.allRead:
        state = state.copyWith(messages: 0);
      case NotificationEventType.created:
        if (event.notification!.isMessage) unawaited(_refreshMessages());
      case NotificationEventType.read:
      case NotificationEventType.deleted:
        // The event does not say which kind it was.
        if (state.messages > 0) unawaited(_refreshMessages());
      case NotificationEventType.init:
        break;
    }
  }

  /// Reads both counts from the server (at start, on app resume and after
  /// the socket reconnects).
  Future<void> refreshFromServer() async {
    if (!ref.mounted || ref.read(sessionUserIdProvider) == null) return;
    try {
      final all = await _repo.getUnreadCount();
      if (ref.mounted) state = state.copyWith(all: all);
    } catch (_) {
      // Keep the last known count.
    }
    await _refreshMessages();
  }

  Future<void> _refreshMessages() async {
    if (!ref.mounted || ref.read(sessionUserIdProvider) == null) return;
    try {
      final messages = await _repo.getUnreadMessageCount();
      if (ref.mounted) state = state.copyWith(messages: messages);
    } catch (_) {
      // Keep the last known count.
    }
  }

  /// The chat with [userId] is open: its message notifications are read
  /// now (saved on the server).
  Future<void> markChatRead(String userId) async {
    if (userId.isEmpty || state.messages == 0) return;
    try {
      final unread = await _repo.getUnreadMessageNotifications();
      for (final n in unread.where((n) => n.isFromUser(userId))) {
        await _repo.markAsRead(n.id);
      }
    } catch (_) {
      // The badge is read again below either way.
    }
    await refreshFromServer();
  }

  void set(UnreadCounts counts) => state = counts;

  /// Change the non-message count by [delta] (read / deleted in the list).
  void adjust(int delta) => state = state.copyWith(all: state.all + delta);
}

final unreadCountsProvider =
    NotifierProvider<UnreadCountsNotifier, UnreadCounts>(
      UnreadCountsNotifier.new,
    );

/// Bell badge: all unread notifications (chat messages too), as on the
/// website.
final unreadNotificationsCountProvider = Provider<int>(
  (ref) => ref.watch(unreadCountsProvider).all,
);

/// Chats tab badge: unread chat message notifications.
final unreadChatsCountProvider = Provider<int>(
  (ref) => ref.watch(unreadCountsProvider).messages,
);
