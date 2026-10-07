import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../home/presentation/widgets/connect_like_you_section.dart'
    show PersonAvatar;
import '../models/chat_message.dart';
import '../../network/presentation/widgets/connect_button.dart';
import '../../network/providers/network_provider.dart';
import '../models/chat_block_status.dart';
import '../providers/chat_access_provider.dart';
import '../providers/chat_block_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_lookup_provider.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';
import 'active_chat.dart';
import 'widgets/chat_attachments.dart';
import 'widgets/chat_emoji_sheet.dart';
import 'widgets/chat_report_sheet.dart';
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

  /// Photo or file picked to send with the next message.
  PickedChatFile? _pending;

  Future<void> _attach() async {
    if (_isSending) return;
    final source = await showAttachmentOptions(context);
    if (source == null || !mounted) return;
    try {
      final file = await ref.read(chatFilePickerProvider)(source);
      if (file == null || !mounted) return;
      if (file.size > ChatRepository.maxAttachmentBytes) {
        _snack('Files must be 10 MB or smaller.', error: true);
        return;
      }
      setState(() => _pending = file);
    } catch (_) {
      if (mounted) _snack('Could not open the file.', error: true);
    }
  }

  /// Phones drop sockets in the background: reconnect as soon as the app
  /// is back instead of waiting for the next backoff step.
  late final AppLifecycleListener _lifecycle;

  /// The chat socket, kept for [dispose] (ref cannot be used there).
  late final ChatWebSocketService _socket;

  /// Set once the screen starts closing after the conversation was deleted.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _socket = ref.read(chatWebSocketServiceProvider);
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(chatWebSocketServiceProvider).retryNow(),
    );
    // No notification banner for this person's messages while open.
    ActiveChat.enter(widget.receiverId);
    // Their message notifications are read now (clears the Chats badge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(unreadCountsProvider.notifier).markChatRead(widget.receiverId);
      _markConversationRead();
    });
  }

  /// Last message from the other person that was marked read.
  String _lastReadIncomingId = '';

  /// Near the top of the list: read the older messages.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 120) return;
    final chat = ref.read(chatMessagesProvider(widget.conversationId));
    if (chat.hasOlder && !chat.loadingOlder && chat.olderError == null) {
      chat.loadOlder();
    }
  }

  /// Older messages were added above: keep the same messages on screen
  /// instead of jumping.
  void _keepPositionAfterPrepend() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final oldMax = position.maxScrollExtent;
    final oldPixels = position.pixels;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final grown = _scrollController.position.maxScrollExtent - oldMax;
      if (grown > 0) _scrollController.jumpTo(oldPixels + grown);
    });
  }

  /// Typing signal: "typing" is sent at most every 3 s while the user
  /// types, "stopped" 3 s after the last key or when the message is sent.
  DateTime? _lastTypingSent;
  Timer? _typingIdle;

  Future<void> _addEmoji() async {
    final emoji = await showEmojiSheet(context);
    if (emoji == null || !mounted) return;
    insertAtCursor(_messageController, emoji);
    _onComposerChanged(_messageController.text);
  }

  void _onComposerChanged(String text) {
    if (text.trim().isEmpty) {
      _sendTyping(false);
      return;
    }
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last == null || now.difference(last) > const Duration(seconds: 3)) {
      _sendTyping(true);
    }
    _typingIdle?.cancel();
    _typingIdle = Timer(const Duration(seconds: 3), () => _sendTyping(false));
  }

  void _sendTyping(bool typing) {
    _typingIdle?.cancel();
    if (!typing && _lastTypingSent == null) return; // nothing to stop
    _lastTypingSent = typing ? DateTime.now() : null;
    ref
        .read(chatWebSocketServiceProvider)
        .sendTyping(
          receiverId: widget.receiverId,
          conversationId: ref
              .read(chatMessagesProvider(widget.conversationId))
              .conversationId,
          isTyping: typing,
        );
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? AppColors.error : null,
          content: Text(text),
        ),
      );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Long-press on the user's own message.
  /// Long-press on a message: Copy text (any message with text) and, for
  /// the user's own message, Delete.
  Future<void> _onMessageLongPress(
    ChatMessage message, {
    required bool isMe,
  }) async {
    final canCopy = message.content.trim().isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCopy)
              ListTile(
                leading: const Icon(
                  Icons.copy_rounded,
                  color: AppColors.textPrimary,
                ),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (isMe)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (mounted) _snack('Message copied.');
      return;
    }
    if (action != 'delete') return;
    final ok = await _confirm(
      title: 'Delete message?',
      message:
          'The message will be removed for both of you. You will both see '
          '"This message was deleted" in its place.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final done = await ref
        .read(chatMessagesProvider(widget.conversationId))
        .deleteMessage(message.id);
    if (!done && mounted) {
      _snack('Could not delete the message. Please try again.', error: true);
    }
  }

  Future<void> _clearChat() async {
    final ok = await _confirm(
      title: 'Clear chat?',
      message:
          'All messages will be cleared for you only. The other person '
          'keeps their copy, and new messages will still arrive here.',
      action: 'Clear',
    );
    if (!ok || !mounted) return;
    final done = await ref
        .read(chatMessagesProvider(widget.conversationId))
        .clearChat();
    if (mounted) {
      _snack(
        done ? 'Chat cleared.' : 'Could not clear the chat. Please try again.',
        error: !done,
      );
    }
  }

  Future<void> _deleteConversation() async {
    final ok = await _confirm(
      title: 'Delete conversation?',
      message:
          'This conversation will be removed from your inbox only. The other '
          'person keeps it, and it comes back if a new message arrives.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final done = await ref
        .read(chatMessagesProvider(widget.conversationId))
        .deleteConversation();
    if (!done && mounted) {
      _snack(
        'Could not delete the conversation. Please try again.',
        error: true,
      );
    }
    // On success the screen closes (see conversationDeleted in build).
  }

  Future<void> _block(String name) async {
    final who = name.isNotEmpty ? name : 'this user';
    final ok = await _confirm(
      title: 'Block $who?',
      message:
          'They will not be able to send you messages on KaamMilega, and you '
          'will not be able to message them. You can unblock them at any '
          'time.',
      action: 'Block',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).blockUser(widget.receiverId);
      if (!mounted) return;
      ref.invalidate(chatBlockStatusProvider(widget.receiverId));
      _snack('$who blocked.');
    } catch (_) {
      if (mounted) _snack('Could not block. Please try again.', error: true);
    }
  }

  Future<void> _unblock(String name) async {
    final who = name.isNotEmpty ? name : 'this user';
    final ok = await _confirm(
      title: 'Unblock $who?',
      message:
          'You will be able to send each other messages on KaamMilega again.',
      action: 'Unblock',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).unblockUser(widget.receiverId);
      if (!mounted) return;
      ref.invalidate(chatBlockStatusProvider(widget.receiverId));
      _snack('$who unblocked.');
    } catch (_) {
      if (mounted) _snack('Could not unblock. Please try again.', error: true);
    }
  }

  Future<void> _report(String name) async {
    final conversationId = ref
        .read(chatMessagesProvider(widget.conversationId))
        .conversationId;
    if (conversationId.isEmpty) return;
    final result = await showChatReportSheet(
      context,
      conversationId: conversationId,
      name: name,
    );
    if (result == null || !mounted) return;
    if (result.blocked) {
      ref.invalidate(chatBlockStatusProvider(widget.receiverId));
    }
    _snack(
      result.reportNumber.isNotEmpty
          ? 'Report ${result.reportNumber} sent. Our team will review it.'
          : 'Report sent. Our team will review it.',
    );
  }

  /// PUT /chats/:id/read: clears this chat's unread count (Chats badge) and
  /// tells the other person their messages were read.
  Future<void> _markConversationRead() async {
    final id = widget.conversationId;
    if (id.isEmpty || id.startsWith('new-')) return; // nothing on the server
    try {
      await ref
          .read(chatRepositoryProvider)
          .markConversationRead(id, otherUserId: widget.receiverId);
      if (mounted) ref.invalidate(conversationsProvider);
    } catch (_) {
      // Stays unread on the server; tried again on the next message.
    }
  }

  @override
  void dispose() {
    _typingIdle?.cancel();
    if (_lastTypingSent != null) {
      // Leaving while typing: tell the other person it stopped.
      _socket.sendTyping(
        receiverId: widget.receiverId,
        conversationId: '',
        isTyping: false,
      );
    }
    ActiveChat.leave(widget.receiverId);
    _lifecycle.dispose();
    _messageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
    final pending = _pending;
    if ((text.isEmpty && pending == null) || _isSending) return;
    // Recruiters directly; anyone else only once connected.
    if (ref.read(chatAccessProvider(widget.receiverId)).value !=
        ChatAccess.allowed) {
      return;
    }
    // Blocked either way: the server refuses, so do not try.
    if (ref.read(chatBlockStatusProvider(widget.receiverId)).value?.isBlocked ??
        false) {
      return;
    }

    setState(() => _isSending = true);
    _sendTyping(false);

    // 1. Upload the picked file (kept, with the text, if this fails).
    ChatAttachment? attachment;
    if (pending != null) {
      try {
        attachment = await ref
            .read(chatRepositoryProvider)
            .uploadAttachment(pending.bytes, pending.name);
      } catch (_) {
        if (mounted) {
          setState(() => _isSending = false);
          _snack('Could not upload the file. Please try again.', error: true);
        }
        return;
      }
    }

    // 2. Send the message.
    final success = await ref
        .read(chatMessagesProvider(widget.conversationId))
        .sendMessage(
          receiverId: widget.receiverId,
          content: text,
          attachment: attachment,
        );

    if (mounted) {
      setState(() {
        _isSending = false;
        if (success) {
          _pending = null;
          _messageController.clear();
        }
      });
      if (success) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      } else {
        // A block the socket did not report yet shows up here.
        ref.invalidate(chatBlockStatusProvider(widget.receiverId));
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
    final looked = ref.watch(userLookupProvider(widget.receiverId)).value;
    // Name, photo and online status of the other person, as sent by
    // GET /chats for this conversation (nothing made up when missing).
    final partner = ref
        .watch(conversationsProvider)
        .value
        ?.where(
          (c) =>
              c.id == widget.conversationId ||
              c.otherUser?.id == widget.receiverId,
        )
        .firstOrNull
        ?.otherUser;
    final name = [
      partner?.name ?? '',
      looked?.name.trim() ?? '',
      widget.title,
    ].firstWhere((n) => n.isNotEmpty, orElse: () => '');
    final other =
        looked ??
        UserProfile(
          id: widget.receiverId,
          mobile: '',
          name: name,
          profileImage: partner?.profileImage ?? '',
        );
    final isOnline = partner?.isOnline ?? false;
    final isTyping = ref.watch(typingUsersProvider).contains(widget.receiverId);
    final subtitle = isTyping
        ? 'typing...'
        : isOnline
        ? 'Online'
        : (partner?.headline ?? '');
    final hasServerChat = chatNotifier.conversationId.isNotEmpty;
    // Previous answer is kept while it reloads (no flicker).
    final accessAsync = ref.watch(chatAccessProvider(widget.receiverId));
    final access = accessAsync.value;
    // Unknown while loading or after an error: not shown as blocked (the
    // server still refuses a blocked message).
    final block =
        ref.watch(chatBlockStatusProvider(widget.receiverId)).value ??
        ChatBlockStatus.none;
    final canSend = access == ChatAccess.allowed && !block.isBlocked;

    // Deleted (here or by the other person): close the chat.
    ref.listen<ChatMessagesNotifier>(
      chatMessagesProvider(widget.conversationId),
      (previous, next) {
        if (next.conversationDeleted && mounted && !_closing) {
          _closing = true;
          ref.invalidate(conversationsProvider);
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).maybePop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Conversation deleted.')),
          );
        }
      },
    );

    // Trigger scroll to bottom when messages update
    ref.listen<ChatMessagesNotifier>(
      chatMessagesProvider(widget.conversationId),
      (previous, next) {
        final before = previous?.messages ?? const <ChatMessage>[];
        final after = next.messages;
        String lastId(List<ChatMessage> list) =>
            list.isEmpty ? '' : '${list.length}:${list.last.id}';
        if (after.length > before.length &&
            before.isNotEmpty &&
            after.isNotEmpty &&
            after.last.id == before.last.id) {
          // Older messages were added above.
          _keepPositionAfterPrepend();
        } else if (lastId(after) != lastId(before)) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
        // A new message from the other person while this chat is open is
        // read at once.
        final last = next.messages.isEmpty ? null : next.messages.last;
        if (last != null &&
            last.id.isNotEmpty &&
            last.senderId != currentUserId &&
            last.id != _lastReadIncomingId) {
          _lastReadIncomingId = last.id;
          _markConversationRead();
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        titleSpacing: 0,
        actions: [
          if (widget.receiverId.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textPrimary,
              ),
              onSelected: (value) => switch (value) {
                'block' => _block(name),
                'unblock' => _unblock(name),
                'report' => _report(name),
                'clear' => _clearChat(),
                _ => _deleteConversation(),
              },
              itemBuilder: (context) => [
                if (block.blockedByMe)
                  const PopupMenuItem(
                    value: 'unblock',
                    child: _MenuRow(
                      icon: Icons.lock_open_rounded,
                      text: 'Unblock user',
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'block',
                    child: _MenuRow(
                      icon: Icons.block_rounded,
                      text: 'Block user',
                    ),
                  ),
                if (hasServerChat) ...[
                  const PopupMenuItem(
                    value: 'report',
                    child: _MenuRow(
                      icon: Icons.flag_outlined,
                      text: 'Report conversation',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'clear',
                    child: _MenuRow(
                      icon: Icons.cleaning_services_outlined,
                      text: 'Clear chat',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: _MenuRow(
                      icon: Icons.delete_outline_rounded,
                      text: 'Delete conversation',
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
        ],
        title: Row(
          children: [
            ExcludeSemantics(child: PersonAvatar(user: other, size: 38)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // The other person's real status from the server; the
                  // connection state is shown by the banner below.
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isOnline && !isTyping) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isTyping
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontStyle: isTyping
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                      itemCount:
                          messages.length + (chatNotifier.hasOlder ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (chatNotifier.hasOlder && i == 0) {
                          return _OlderMessagesHeader(
                            loading: chatNotifier.loadingOlder,
                            failed: chatNotifier.olderError != null,
                            onLoad: chatNotifier.loadOlder,
                          );
                        }
                        final index = chatNotifier.hasOlder ? i - 1 : i;
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
                            // Copy any text; only the sender can delete.
                            onLongPress:
                                msg.id.isNotEmpty &&
                                    !msg.isDeleted &&
                                    (isMe || msg.content.trim().isNotEmpty)
                                ? () => _onMessageLongPress(msg, isMe: isMe)
                                : null,
                          ),
                        );
                      },
                    ),
            ),

            if (block.blockedByMe)
              _BlockedBar(
                text:
                    'You blocked ${name.isNotEmpty ? name : 'this user'}. '
                    'Unblock to send messages.',
                onUnblock: () => _unblock(name),
              )
            else if (block.blockedByOther)
              const _BlockedBar(
                text:
                    'You cannot send messages to this conversation right now.',
              )
            else if (access != null && access != ChatAccess.allowed)
              _ConnectFirstBar(
                userId: widget.receiverId,
                name: name,
                pending: access == ChatAccess.requestPending,
              )
            else if (access == null && accessAsync.hasError)
              _AccessErrorBar(
                onRetry: () {
                  ref.invalidate(connectionStatusProvider(widget.receiverId));
                  ref.invalidate(chatAccessProvider(widget.receiverId));
                },
              )
            else
              // Message composer: one rounded bar with attach, emoji, text
              // and send (send waits for the connection check).
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: const Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandNavy.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pending != null)
                      PendingAttachmentPreview(
                        file: _pending!,
                        onRemove: _isSending
                            ? null
                            : () => setState(() => _pending = null),
                      ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _ComposerIcon(
                            tooltip: 'Attach photo or file',
                            icon: Icons.attach_file_rounded,
                            onPressed: _isSending ? null : _attach,
                          ),
                          _ComposerIcon(
                            tooltip: 'Add emoji',
                            icon: Icons.sentiment_satisfied_alt_outlined,
                            onPressed: _isSending ? null : _addEmoji,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _sendMessage(),
                              onChanged: _onComposerChanged,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PressableScale(
                            pressedScale: 0.9,
                            child: Material(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: IconButton(
                                tooltip: 'Send',
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: AppColors.white,
                                          size: 20,
                                        ),
                                ),
                                onPressed: _isSending || !canSend
                                    ? null
                                    : _sendMessage,
                              ),
                            ),
                          ),
                        ],
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
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMe;
  final UserProfile author;
  final bool showAvatar;
  final VoidCallback? onLongPress;

  static const double _avatarSize = 28;

  @override
  Widget build(BuildContext context) {
    // A deleted message is a plain outlined note for both people (no
    // colour, no shadow, no read ticks), so it never looks like a message.
    final deleted = message.isDeleted;
    final timeColor = deleted
        ? AppColors.textLight
        : isMe
        ? AppColors.white.withValues(alpha: 0.75)
        : AppColors.textLight;
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
          padding: EdgeInsets.symmetric(
            horizontal: deleted ? 14 : 16,
            vertical: deleted ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: deleted
                ? AppColors.white.withValues(alpha: 0.6)
                : isMe
                ? AppColors.primary
                : AppColors.white,
            border: deleted ? Border.all(color: AppColors.border) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe || !showAvatar ? 18 : 4),
              bottomRight: Radius.circular(!isMe || !showAvatar ? 18 : 4),
            ),
            boxShadow: deleted
                ? null
                : [
                    BoxShadow(
                      color: AppColors.brandNavy.withValues(alpha: 0.03),
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
              if (deleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'This message was deleted',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              if (message.attachment != null && !message.isDeleted)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: message.content.isNotEmpty ? 6 : 0,
                  ),
                  child: MessageAttachmentView(
                    attachment: message.attachment!,
                    isMe: isMe,
                  ),
                ),
              if (message.content.isNotEmpty && !message.isDeleted)
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isMe ? AppColors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.formattedTime,
                    style: TextStyle(fontSize: 10, color: timeColor),
                  ),
                  // Ticks on the user's own messages: one when sent, two
                  // when the other person has read it.
                  if (isMe && !deleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: message.isRead
                          ? AppColors.white
                          : AppColors.white.withValues(alpha: 0.75),
                      semanticLabel: message.isRead ? 'Read' : 'Sent',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 12 : 4),
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: isMe
              ? [bubble, const SizedBox(width: 8), avatar]
              : [avatar, const SizedBox(width: 8), bubble],
        ),
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

/// Grey icon button inside the message bar.
class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: AppColors.textSecondary, size: 22),
    );
  }
}

/// Shown instead of the message box when the other person is not a
/// recruiter and not a connection yet.
/// Icon and label in the chat options menu.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 12),
        Flexible(
          child: Text(text, style: TextStyle(color: c)),
        ),
      ],
    );
  }
}

/// Top of the list when older messages exist: loading, Retry after a
/// failure, or a button (scrolling to the top also loads them).
class _OlderMessagesHeader extends StatelessWidget {
  const _OlderMessagesHeader({
    required this.loading,
    required this.failed,
    required this.onLoad,
  });

  final bool loading;
  final bool failed;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onLoad,
                icon: Icon(
                  failed ? Icons.refresh_rounded : Icons.history_rounded,
                  size: 18,
                ),
                label: Text(
                  failed
                      ? 'Could not load earlier messages. Retry'
                      : 'Load earlier messages',
                ),
              ),
      ),
    );
  }
}

/// Composer replaced while either person blocked the other.
class _BlockedBar extends StatelessWidget {
  const _BlockedBar({required this.text, this.onUnblock});

  final String text;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.block_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (onUnblock != null)
              TextButton(onPressed: onUnblock, child: const Text('Unblock'))
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _ConnectFirstBar extends StatelessWidget {
  const _ConnectFirstBar({
    required this.userId,
    required this.name,
    required this.pending,
  });

  final String userId;
  final String name;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final who = name.isNotEmpty ? name : 'this person';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pending ? 'Connection request pending' : 'Connect to chat',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pending
                        ? 'You can message $who once the request is accepted.'
                        : 'Connect with $who to send messages.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConnectButton(userId: userId, name: who),
          ],
        ),
      ),
    );
  }
}

/// The connection check failed: say so and offer Retry (sending stays
/// off; a failed check is never treated as allowed).
class _AccessErrorBar extends StatelessWidget {
  const _AccessErrorBar({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Could not check if you can message this person.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
