import 'notification_item.dart';

/// Where tapping a notification takes the user in the app.
sealed class NotificationTarget {
  const NotificationTarget();
}

/// An app route, e.g. `/my-applications`.
class RouteTarget extends NotificationTarget {
  const RouteTarget(this.path);
  final String path;

  @override
  bool operator ==(Object other) => other is RouteTarget && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'RouteTarget($path)';
}

/// The chat with [userId] ([conversationId] when the server sent it).
class ChatTarget extends NotificationTarget {
  const ChatTarget({
    required this.userId,
    this.conversationId = '',
    this.title = 'Chat',
  });

  final String userId;
  final String conversationId;
  final String title;

  /// `/chats/:id` route of the app (`new-<user>` before a conversation
  /// exists, as in `openChatWithUser`).
  String get route =>
      '/chats/${conversationId.isNotEmpty ? conversationId : 'new-$userId'}';

  @override
  bool operator ==(Object other) =>
      other is ChatTarget &&
      other.userId == userId &&
      other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(userId, conversationId);

  @override
  String toString() => 'ChatTarget($userId, $conversationId)';
}

/// Turns the website link of [item] into an app screen.
///
/// km-backend stores website paths in `link`. Recruiter-only pages
/// (`/recruiter/...`, `/instant-hire`) and unknown paths return null, so a
/// tap only marks the notification as read instead of opening a broken
/// page.
NotificationTarget? notificationTarget(NotificationItem item) {
  final uri = Uri.tryParse(item.link.trim());
  final path = (uri?.path ?? '').replaceAll(RegExp(r'/+$'), '');
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  // Chat: link `/chat?user=<id>`; the conversation is in metadata.
  if (item.type == 'chat_message' || path == '/chat' || path == '/chats') {
    final userId = [
      uri?.queryParameters['user'] ?? '',
      item.meta('sender_id'),
      item.actorId,
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (userId.isEmpty) return null;
    return ChatTarget(
      userId: userId,
      conversationId: item.meta('conversation_id'),
      title: item.actorName.isNotEmpty ? item.actorName : 'Chat',
    );
  }

  // Accepted invite: the person who accepted (as on the website).
  if (item.type == 'connection_accepted') {
    final id = item.actorId.isNotEmpty
        ? item.actorId
        : item.meta('accepted_by');
    if (id.isNotEmpty) return RouteTarget('/members/$id');
  }

  if (segments.isEmpty) return null;
  switch (segments.first) {
    case 'applications':
      return const RouteTarget('/my-applications');
    case 'interviews':
      return const RouteTarget('/interviews');
    case 'network':
      // Connection requests open the Pending Requests tab.
      return item.type == 'connection_request'
          ? const RouteTarget('/network?tab=pending')
          : const RouteTarget('/network');
    case 'profile':
      return segments.length > 1
          ? RouteTarget('/members/${segments[1]}')
          : const RouteTarget('/profile');
    case 'wallet':
      const walletPages = {'transactions', 'disputes'};
      return segments.length > 1 && walletPages.contains(segments[1])
          ? RouteTarget('/wallet/${segments[1]}')
          : const RouteTarget('/wallet');
    case 'mentorship':
      return const RouteTarget('/my-sessions');
    case 'expert':
      return segments.length > 1 && segments[1] == 'mentorship'
          ? const RouteTarget('/expert-dashboard')
          : null;
    case 'events':
      // Registration and ticket confirmations: the ticket is in My Tickets.
      return item.type == 'event_confirmed'
          ? const RouteTarget('/my-tickets')
          : const RouteTarget('/events');
    case 'instant-work':
      return const RouteTarget('/instant-work');
    case 'candidate':
      // Older links: /candidate/applications, /candidate/interviews.
      if (segments.length > 1 && segments[1] == 'applications') {
        return const RouteTarget('/my-applications');
      }
      if (segments.length > 1 && segments[1] == 'interviews') {
        return const RouteTarget('/interviews');
      }
      return null;
    default:
      return null; // recruiter pages, unknown paths
  }
}

/// Label of the quick action button on a notification row (null: none),
/// the same labels as the website.
String? notificationActionLabel(NotificationItem item) {
  if (notificationTarget(item) == null) return null;
  if (item.isMessage) return 'Reply';
  switch (item.type) {
    case 'application_received':
      return 'Review';
    case 'application_status':
    case 'interview_scheduled':
    case 'connection_request':
      return 'View';
    case 'connection_accepted':
      return 'Profile';
  }
  return 'Open';
}
