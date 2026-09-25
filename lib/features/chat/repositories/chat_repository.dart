import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../../../core/network/response_list.dart';

/// Repository for handling Chat HTTP API calls with km-backend
class ChatRepository {
  final ApiClient _client;

  ChatRepository(this._client);

  /// Fetch candidate's active conversations
  /// Throws on failure so the screen can show an error, not "no chats".
  Future<List<ConversationItem>> getConversations() async {
    final response = await _client.get(ApiConstants.chats);
    return readListResponse(response.data)
        .map(ConversationItem.fromJson)
        .toList();
  }

  /// Send a message to a user
  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    final response = await _client.post(
      ApiConstants.chatMessages,
      data: {'receiver_id': receiverId, 'content': content},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch message history for a specific conversation ID
  /// Throws on failure so the chat can show an error, not an empty chat.
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get(
      '${ApiConstants.chatMessagesList}$conversationId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return readListResponse(response.data).map(ChatMessage.fromJson).toList();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
