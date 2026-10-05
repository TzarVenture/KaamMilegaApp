import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../auth/models/user_profile.dart';
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

  /// Send a message to a user, with an optional uploaded [attachment]
  /// (POST /chats/messages; text, attachment or both).
  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String content,
    ChatAttachment? attachment,
  }) async {
    final response = await _client.post(
      ApiConstants.chatMessages,
      data: {
        'receiver_id': receiverId,
        'content': content,
        if (attachment != null) ...{
          'attachment_url': attachment.url,
          'attachment_type': attachment.type,
          'attachment_name': attachment.name,
          'attachment_size': attachment.size,
        },
      },
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

  /// PUT /chats/:id/read?other_id= — the signed-in user has read this
  /// conversation; the other person gets a live "read" receipt.
  Future<void> markConversationRead(
    String conversationId, {
    String otherUserId = '',
  }) async {
    await _client.put(
      ApiConstants.chatRead(conversationId),
      queryParameters: {if (otherUserId.isNotEmpty) 'other_id': otherUserId},
    );
  }

  /// Largest file accepted for a chat message (same as the website).
  static const int maxAttachmentBytes = 10 * 1024 * 1024;

  /// POST /files/upload (multipart `file`) -> the uploaded file's link,
  /// type, name and size, to send with a message.
  Future<ChatAttachment> uploadAttachment(
    List<int> bytes,
    String filename,
  ) async {
    final type = mimeTypeFor(filename);
    final response = await _client.post(
      ApiConstants.fileUpload,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(type),
        ),
      }),
    );
    final data = response.data;
    final url = data is Map ? (data['url']?.toString() ?? '') : '';
    if (url.isEmpty) {
      throw const AppValidationException(
        'The file could not be uploaded. Please try again.',
      );
    }
    final size = data['size'];
    final serverType = data['mime_type']?.toString() ?? '';
    return ChatAttachment(
      url: url,
      type: serverType.isNotEmpty && serverType != 'application/octet-stream'
          ? serverType
          : type,
      name: data['original_filename']?.toString().isNotEmpty == true
          ? data['original_filename'].toString()
          : filename,
      size: size is num && size > 0 ? size.toInt() : bytes.length,
    );
  }

  /// MIME type from the file name (sent with the upload so the server and
  /// the other person's app know what the file is).
  static String mimeTypeFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  /// DELETE /chats/messages/:id — deletes the message for both people.
  Future<void> deleteMessage(String messageId) async {
    await _client.delete('${ApiConstants.chatMessagesList}messages/$messageId');
  }

  /// DELETE /chats/:id/messages — deletes every message for both people.
  Future<void> clearChat(String conversationId) async {
    await _client.delete(
      '${ApiConstants.chatMessagesList}$conversationId/messages',
    );
  }

  /// DELETE /chats/:id — deletes the conversation for both people.
  Future<void> deleteConversation(String conversationId) async {
    await _client.delete('${ApiConstants.chatMessagesList}$conversationId');
  }

  /// GET /user/search?q= — people to start a new chat with.
  Future<List<UserProfile>> searchPeople(String query) async {
    final response = await _client.get(
      ApiConstants.userSearch,
      queryParameters: {'q': query, 'limit': 20},
    );
    return readListResponse(response.data).map(UserProfile.fromJson).toList();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
