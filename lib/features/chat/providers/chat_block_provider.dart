import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/chat_block_status.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';

/// Block status with another person (GET /chats/users/:id/block-status).
/// Reloads by itself when either person blocks or unblocks (USER_BLOCKED /
/// USER_UNBLOCKED on the chat socket). Guests have no block status.
final chatBlockStatusProvider = FutureProvider.autoDispose
    .family<ChatBlockStatus, String>((ref, otherUserId) {
      if (ref.watch(sessionUserIdProvider) == null || otherUserId.isEmpty) {
        return ChatBlockStatus.none;
      }
      final events = ref.watch(chatWebSocketServiceProvider).events.listen((
        event,
      ) {
        if (event is BlockChangedEvent && event.otherUserId == otherUserId) {
          ref.invalidateSelf();
        }
      });
      ref.onDispose(events.cancel);
      return ref.watch(chatRepositoryProvider).getBlockStatus(otherUserId);
    });
