import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/chat_websocket_service.dart';

/// Screen for 1-on-1 Real-Time Chat Conversation
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String receiverId;
  final String title;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
    this.title = 'Chat',
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final success = await ref
        .read(chatMessagesProvider(widget.conversationId))
        .sendMessage(receiverId: widget.receiverId, content: text);

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to send message. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatNotifier = ref.watch(chatMessagesProvider(widget.conversationId));
    final messages = chatNotifier.messages;
    final currentUser = ref.watch(authProvider).user;
    final currentUserId = currentUser?.id ?? '';
    final wsStatusAsync = ref.watch(webSocketStatusStreamProvider);
    final wsStatus = wsStatusAsync.value ?? WebSocketStatus.connected;

    // Trigger scroll to bottom when messages update
    ref.listen<ChatMessagesNotifier>(
      chatMessagesProvider(widget.conversationId),
      (previous, next) {
        if (next.messages.length != (previous?.messages.length ?? 0)) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: wsStatus == WebSocketStatus.connected
                        ? AppColors.success
                        : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  wsStatus == WebSocketStatus.connected
                      ? 'Live Chat Online'
                      : 'Connecting...',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // WebSocket Status Banner if disconnected/reconnecting
            if (wsStatus == WebSocketStatus.connecting ||
                wsStatus == WebSocketStatus.error)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                color: AppColors.warning.withValues(alpha: 0.15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.warning,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reconnecting live chat...',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            // Messages List
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: AppColors.textLight,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Say hello!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Send a message to start real-time conversation.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUserId;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: isMe
                                    ? const Radius.circular(18)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: isMe
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg.formattedTime,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white70
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Message Composer Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
