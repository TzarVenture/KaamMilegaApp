import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';

/// Opens a 1-on-1 chat with [receiverId].
///
/// If a conversation with this person already exists, it is opened with its
/// real ID so the message history loads. Otherwise a new chat screen opens;
/// the conversation is created on the server when the first message is sent
/// (POST /chats/messages).
Future<void> openChatWithUser(
  BuildContext context,
  WidgetRef ref, {
  required String receiverId,
  required String title,
}) async {
  if (receiverId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This person is not available for chat right now.'),
      ),
    );
    return;
  }

  var conversationId = '';
  try {
    final conversations = await ref.read(conversationsProvider.future);
    for (final conv in conversations) {
      if (conv.participants.contains(receiverId)) {
        conversationId = conv.id;
        break;
      }
    }
  } catch (_) {
    // Offline or unavailable: fall back to a new chat screen
  }

  if (!context.mounted) return;
  context.push(
    '/chats/${conversationId.isNotEmpty ? conversationId : 'new-$receiverId'}',
    extra: {'receiverId': receiverId, 'title': title},
  );
}
