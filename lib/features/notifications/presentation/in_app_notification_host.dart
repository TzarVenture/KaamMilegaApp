import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/notification_sound.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/active_chat.dart';
import '../../network/providers/network_provider.dart';
import '../models/notification_item.dart';
import '../models/notification_target.dart';
import '../providers/notification_provider.dart';
import '../services/notification_socket_service.dart';
import 'widgets/notification_visuals.dart';

/// Keeps the live notification connection open while the app runs and
/// shows a short banner at the top for each new notification.
///
/// - connects for signed-in users only (a new connection per account);
/// - reconnects and re-reads the unread count when the app comes back to
///   the foreground;
/// - no banner for a chat message from the person whose chat is open, or
///   while the app is in the background;
/// - the banner closes after [displayDuration], on swipe up or on X; a tap
///   opens the notification's screen and marks it read.
class InAppNotificationHost extends ConsumerStatefulWidget {
  const InAppNotificationHost({
    super.key,
    required this.router,
    required this.child,
    this.displayDuration = const Duration(seconds: 5),
  });

  final GoRouter router;
  final Widget child;
  final Duration displayDuration;

  @override
  ConsumerState<InAppNotificationHost> createState() =>
      _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost>
    with WidgetsBindingObserver {
  NotificationItem? _current;
  Timer? _hideTimer;
  StreamSubscription<void>? _reconnectSub;
  bool _inForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A new service is created on login, logout and account switch.
    ref.listenManual<NotificationSocketService>(
      notificationSocketServiceProvider,
      (_, service) => _attach(service),
      fireImmediately: true,
    );
    ref.listenManual<AsyncValue<NotificationEvent>>(
      notificationEventsProvider,
      (_, next) {
        final event = next.value;
        if (event?.type == NotificationEventType.created) {
          _refreshConnection(event!.notification!);
          _maybeShow(event.notification!);
        }
      },
    );
    // Keeps the unread badge (and its socket updates) alive app-wide.
    ref.listenManual<UnreadCounts>(unreadCountsProvider, (_, _) {});
  }

  void _attach(NotificationSocketService service) {
    _reconnectSub?.cancel();
    // Never leave the previous account's banner on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _hide());
    if (ref.read(sessionUserIdProvider) == null) return;
    _reconnectSub = service.reconnected.listen(
      (_) => ref.read(unreadCountsProvider.notifier).refreshFromServer(),
    );
    unawaited(service.connect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (!_inForeground || ref.read(sessionUserIdProvider) == null) return;
    ref.read(notificationSocketServiceProvider).retryNow();
    ref.read(unreadCountsProvider.notifier).refreshFromServer();
  }

  /// A connection request or acceptance from someone changes their
  /// Connect / Pending / Message button, wherever it is on screen.
  void _refreshConnection(NotificationItem item) {
    if (item.type != 'connection_request' &&
        item.type != 'connection_accepted') {
      return;
    }
    final ids = {item.actorId, item.meta('sender_id'), item.meta('accepted_by')}
      ..remove('');
    for (final id in ids) {
      ref.invalidate(connectionStatusProvider(id));
    }
    ref.invalidate(pendingInvitationsProvider);
    ref.invalidate(connectionsProvider);
  }

  void _maybeShow(NotificationItem item) {
    if (!mounted || !_inForeground) return;
    final target = notificationTarget(item);
    final openChat = ActiveChat.partnerId.value;
    if (target is ChatTarget && openChat != null && target.userId == openChat) {
      // Already reading this person's chat: no banner, and the message is
      // read, so the Chats badge does not count it.
      unawaited(
        ref
            .read(notificationRepositoryProvider)
            .markAsRead(item.id)
            .then((_) {}, onError: (_) {}),
      );
      return;
    }
    // A chat message from someone whose chat is not open: a short tone
    // (as on the website). Muted while chatting with that person (above).
    if (target is ChatTarget) {
      unawaited(ref.read(notificationSoundProvider)());
    }
    _hideTimer?.cancel();
    setState(() => _current = item);
    _hideTimer = Timer(widget.displayDuration, _hide);
  }

  void _hide() {
    _hideTimer?.cancel();
    if (mounted && _current != null) setState(() => _current = null);
  }

  void _open(NotificationItem item) {
    _hide();
    unawaited(
      ref
          .read(notificationRepositoryProvider)
          .markAsRead(item.id)
          .then((_) {}, onError: (_) {}),
    );
    final target = notificationTarget(item);
    if (target != null) {
      openNotificationTarget(widget.router, target);
    } else {
      widget.router.push('/notifications');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: item == null
                  ? const SizedBox(
                      key: ValueKey('none'),
                      width: double.infinity,
                    )
                  : Align(
                      key: ValueKey('${item.id}-${item.message}'),
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Dismissible(
                            key: ValueKey('dismiss-${item.id}'),
                            direction: DismissDirection.up,
                            onDismissed: (_) => _hide(),
                            child: InAppNotificationBanner(
                              item: item,
                              onTap: () => _open(item),
                              onClose: _hide,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The card shown at the top for a new notification.
class InAppNotificationBanner extends StatelessWidget {
  const InAppNotificationBanner({
    super.key,
    required this.item,
    required this.onTap,
    required this.onClose,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = item.title.isNotEmpty ? item.title : 'New notification';
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: AppColors.white,
        elevation: 6,
        shadowColor: AppColors.brandNavy.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                NotificationAvatar(item: item, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.message.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // No tooltip: the banner sits above the app's navigator,
                // where there is no Overlay to show one.
                Semantics(
                  button: true,
                  label: 'Dismiss',
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
