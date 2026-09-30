import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/presentation/widgets/connect_like_you_section.dart'
    show PersonAvatar;
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/user_lookup_provider.dart';
import '../services/chat_websocket_service.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/network_state_view.dart';

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

  /// Phones drop sockets in the background: reconnect as soon as the app
  /// is back instead of waiting for the next backoff step.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(chatWebSocketServiceProvider).retryNow(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
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
    final wsStatus =
        ref.watch(webSocketStatusStreamProvider).value ??
        ref.watch(chatWebSocketServiceProvider).status;
    // Small photos next to the messages (initial when there is no photo).
    final me =
        currentUser ?? const UserProfile(id: '', mobile: '', name: 'You');
    final other =
        ref.watch(userLookupProvider(widget.receiverId)).value ??
        UserProfile(id: widget.receiverId, mobile: '', name: widget.title);

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
        titleSpacing: 0,
        title: Row(
          children: [
            ExcludeSemantics(child: PersonAvatar(user: other, size: 38)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                      Flexible(
                        child: Text(
                          switch (wsStatus) {
                            WebSocketStatus.connected => 'Live Chat Online',
                            WebSocketStatus.connecting => 'Connecting...',
                            _ => 'Reconnecting...',
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live-updates banner: only while the socket is not connected.
            // Sending still works (it goes over the normal API).
            if (wsStatus != WebSocketStatus.connected)
              _LiveStatusBanner(
                status: wsStatus,
                onRetry: () =>
                    ref.read(chatWebSocketServiceProvider).retryNow(),
              ),

            // Messages List
            Expanded(
              // History loading / failed: shimmer or error with Retry (a
              // failed load is never shown as an empty chat).
              child: messages.isEmpty && chatNotifier.isLoading
                  ? const ShimmerLoadingList(count: 5, itemHeight: 56)
                  : messages.isEmpty && chatNotifier.error != null
                  ? NetworkStateView.fromError(
                      chatNotifier.error!,
                      onRetry: chatNotifier.retryHistory,
                    )
                  : messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 32,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 14),
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
                              textAlign: TextAlign.center,
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
                        // One photo per run of messages from the same
                        // person, next to the last bubble of the run.
                        final next = index + 1 < messages.length
                            ? messages[index + 1]
                            : null;
                        final showAvatar =
                            next == null || next.senderId != msg.senderId;

                        // Only the newest message eases in (sent or
                        // received); older history appears instantly.
                        return FadeSlideIn(
                          index: index == messages.length - 1 ? 0 : -1,
                          offsetY: 8,
                          child: _MessageRow(
                            message: msg,
                            isMe: isMe,
                            author: isMe ? me : other,
                            showAvatar: showAvatar,
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
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    pressedScale: 0.9,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: _isSending
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
                        ),
                        onPressed: _isSending ? null : _sendMessage,
                      ),
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

/// A message bubble with the author's small round photo beside it: the
/// other person on the left, the signed-in user on the right.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isMe,
    required this.author,
    required this.showAvatar,
  });

  final ChatMessage message;
  final bool isMe;
  final UserProfile author;
  final bool showAvatar;

  static const double _avatarSize = 28;

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox(
      width: _avatarSize,
      child: showAvatar
          ? ExcludeSemantics(
              child: PersonAvatar(user: author, size: _avatarSize),
            )
          : null,
    );
    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe || !showAvatar ? 18 : 4),
              bottomRight: Radius.circular(!isMe || !showAvatar ? 18 : 4),
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
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 12 : 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe
            ? [bubble, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), bubble],
      ),
    );
  }
}

/// Shown while live updates are off: "Connecting" on the first try, then a
/// plain message with Retry. Messages can still be sent meanwhile.
class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({required this.status, required this.onRetry});

  final WebSocketStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final connecting = status == WebSocketStatus.connecting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      color: AppColors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          if (connecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.warning,
              ),
            )
          else
            const Icon(
              Icons.wifi_off_rounded,
              size: 14,
              color: AppColors.warning,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connecting
                  ? 'Connecting live chat...'
                  : 'Live updates paused. You can still send messages.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!connecting)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}
