import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Repository for handling Chat HTTP API calls with km-backend
class ChatRepository {
  final ApiClient _client;

  ChatRepository(this._client);

  /// Fetch candidate's active conversations
  Future<List<ConversationItem>> getConversations() async {
    try {
      final response = await _client.get(ApiConstants.chats);
      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['data'] is List) {
        list = body['data'];
      }

      return list
          .map((e) => ConversationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
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
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.chatMessagesList}$conversationId/messages',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['data'] is List) {
        list = body['data'];
      }

      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
