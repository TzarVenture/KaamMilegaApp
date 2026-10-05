import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../network/providers/network_provider.dart';
import 'chat_provider.dart';
import 'user_lookup_provider.dart';

/// Whether the signed-in user may send messages to another person.
enum ChatAccess {
  /// Recruiter, or an accepted connection.
  allowed,

  /// No connection: the user has to connect first.
  notConnected,

  /// A connection request exists but is not accepted yet.
  requestPending,
}

/// Recruiters can be messaged directly; anyone else only after the
/// connection is accepted (GET /network/status/:id is `accepted`).
///
/// Roles come from GET /chats (`otherUser.roles`) or GET /user/:id. A
/// failed status check is an error (shown with Retry), never "allowed".
final chatAccessProvider = FutureProvider.family<ChatAccess, String>((
  ref,
  otherUserId,
) async {
  if (ref.watch(sessionUserIdProvider) == null || otherUserId.isEmpty) {
    return ChatAccess.notConnected;
  }

  var roles = <String>[];
  try {
    // read, not watch: the list refreshes on every message.
    final conversations = await ref.read(conversationsProvider.future);
    for (final c in conversations) {
      final partner = c.otherUser;
      if (partner != null && partner.id == otherUserId) {
        roles = partner.roles;
        break;
      }
    }
  } catch (_) {
    // Fall back to the profile below.
  }
  if (roles.isEmpty) {
    final profile = await ref.watch(userLookupProvider(otherUserId).future);
    roles = profile?.roles ?? const [];
  }
  if (roles.contains('recruiter')) return ChatAccess.allowed;

  // '' none, pending, accepted, ignored (backend network.ConnectionStatus).
  final status = await ref.watch(connectionStatusProvider(otherUserId).future);
  switch (status) {
    case 'accepted':
      return ChatAccess.allowed;
    case 'pending':
    case 'ignored': // the server refuses a second request while one exists
      return ChatAccess.requestPending;
    default:
      return ChatAccess.notConnected;
  }
});
