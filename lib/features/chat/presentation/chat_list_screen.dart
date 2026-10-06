import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/login_required_view.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../notifications/services/notification_socket_service.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/user_lookup_provider.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';
import 'open_chat.dart';

/// Chats tab: "Messages" with All Chats / Unread, a search that filters the
/// chats and finds people to message, and the conversation list (name,
/// photo, online dot, last message, time and unread count from GET /chats).
class ChatListScreen extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateTab;

  const ChatListScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  /// Turns the refresh icon while the list reloads.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _refreshing = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _unreadOnly = false;

  /// Chats deleted here; hidden until the refreshed list arrives.
  final Set<String> _deletedIds = {};

  // People search (GET /user/search), for starting a new chat.
  Timer? _searchDebounce;
  int _searchSeq = 0;
  bool _searchingPeople = false;
  Object? _peopleError;
  List<UserProfile> _people = const [];

  String get _query => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    // Live connection for typing indicators and deletions in this list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AuthGuard.isSignedIn(ref.read(authProvider))) {
        ref.read(chatWebSocketServiceProvider).connect();
      }
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    final query = _query;
    setState(() {
      if (query.length < 2) {
        _searchSeq++;
        _people = const [];
        _peopleError = null;
        _searchingPeople = false;
      } else {
        _searchingPeople = true;
      }
    });
    if (query.length < 2) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPeople(query),
    );
  }

  Future<void> _searchPeople(String query) async {
    final seq = ++_searchSeq;
    try {
      final me = ref.read(sessionUserIdProvider);
      final found = await ref.read(chatRepositoryProvider).searchPeople(query);
      if (!mounted || seq != _searchSeq) return; // a newer search won
      setState(() {
        _people = found.where((u) => u.id.isNotEmpty && u.id != me).toList();
        _peopleError = null;
        _searchingPeople = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _people = const [];
        _peopleError = e;
        _searchingPeople = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _refresh() async {
    ref.invalidate(conversationsProvider);
    try {
      await ref.read(conversationsProvider.future);
    } catch (_) {
      // Shown by the error state.
    }
  }

  /// Refresh button: the icon keeps turning until the list has reloaded,
  /// then finishes its turn (no spin when the phone's animations are off).
  Future<void> _refreshFromButton() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final animate = !MediaQuery.of(context).disableAnimations;
    if (animate) _spin.repeat();
    await _refresh();
    if (!mounted) return;
    if (animate) {
      await _spin.forward();
      if (!mounted) return;
      _spin.reset();
    }
    setState(() => _refreshing = false);
  }

  Future<void> _openConversation(
    ConversationItem conv,
    String otherUserId,
    String name,
  ) async {
    await context.push(
      '/chats/${conv.id}',
      extra: <String, String>{'receiverId': otherUserId, 'title': name},
    );
    // Back from the chat: last message and unread count may have changed.
    if (mounted) ref.invalidate(conversationsProvider);
  }

  /// Long-press on a chat: offer to delete it.
  Future<void> _onConversationLongPress(
    ConversationItem conv,
    String name,
  ) async {
    final delete = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
          title: const Text(
            'Delete chat',
            style: TextStyle(color: AppColors.error),
          ),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (delete == true && mounted) await _deleteConversation(conv, name);
  }

  /// DELETE /chats/:id after a confirmation. The server hides the
  /// conversation for this user only (it comes back with a new message).
  /// True when deleted.
  Future<bool> _deleteConversation(ConversationItem conv, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'Your chat with $name will be removed from your inbox only. '
          '$name keeps it, and it comes back if a new message arrives.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatRepositoryProvider).deleteConversation(conv.id);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not delete the chat. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
    if (!mounted) return true;
    setState(() => _deletedIds.add(conv.id));
    messenger.showSnackBar(const SnackBar(content: Text('Chat deleted.')));
    ref.invalidate(conversationsProvider);
    return true;
  }

  Future<void> _messagePerson(UserProfile user) async {
    _clearSearch();
    await openChatWithUser(
      context,
      ref,
      receiverId: user.id,
      title: displayNameFor(user),
    );
    if (mounted) ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    // Chats are account-only: guests get a sign-in prompt and the
    // conversations API is not called for them.
    final signedIn = AuthGuard.isSignedIn(auth);
    final conversationsAsync = signedIn
        ? ref.watch(conversationsProvider)
        : null;

    // A new message arrived (live notification): refresh the list so its
    // last message, time and unread count are current.
    if (signedIn) {
      ref.listen(notificationEventsProvider, (_, next) {
        final event = next.value;
        if (event?.type == NotificationEventType.created &&
            event!.notification!.isMessage) {
          ref.invalidate(conversationsProvider);
        }
      });
      // Deleted chats are hidden only until the server list reloads: the
      // server leaves them out itself, and brings one back when a new
      // message arrives in it.
      ref.listen(conversationsProvider, (_, next) {
        if (next.hasValue && !next.isLoading) _deletedIds.clear();
      });
      // A message deleted, a chat cleared or a conversation deleted
      // (by either person): refresh the list.
      ref.listen(chatEventsProvider, (_, next) {
        final event = next.value;
        if (event is MessageDeletedEvent ||
            event is ChatClearedEvent ||
            event is ConversationDeletedEvent) {
          ref.invalidate(conversationsProvider);
        }
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      endDrawer: ProfileDrawer(onNavigateTab: widget.onNavigateTab),
      appBar: _buildAppBar(),
      body: conversationsAsync == null
          ? const LoginRequiredView(
              title: 'Sign in to view your chats',
              message:
                  'Chat with recruiters and your connections after signing '
                  'in.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(conversationsAsync),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.brandNavy,
                    onRefresh: _refresh,
                    child: conversationsAsync.when(
                      data: _buildList,
                      loading: () => const _ListLoading(),
                      error: (error, _) =>
                          NetworkStateView.fromError(error, onRetry: _refresh),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0.5,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: GestureDetector(
        onTap: () {
          if (widget.onNavigateTab != null) {
            widget.onNavigateTab!(0);
          } else {
            context.go('/home');
          }
        },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 30),
              const SizedBox(width: 8),
              Image.asset('assets/images/logo_text.png', height: 18),
            ],
          ),
        ),
      ),
      actions: [
        const NotificationBellButton(),
        IconButton(
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildHeader(AsyncValue<List<ConversationItem>> conversations) {
    final unreadChats =
        conversations.value?.where((c) => c.unreadCount > 0).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandNavy,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refreshing || conversations.isLoading
                    ? null
                    : _refreshFromButton,
                icon: RotationTransition(
                  turns: _spin,
                  child: Icon(
                    Icons.sync_rounded,
                    color: _refreshing
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SegmentedTabs(
            unreadOnly: _unreadOnly,
            unreadCount: unreadChats,
            onChanged: (value) => setState(() => _unreadOnly = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search chats or find people...',
              hintStyle: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<ConversationItem> conversations) {
    final me = ref.watch(sessionUserIdProvider) ?? '';
    final typing = ref.watch(typingUsersProvider);
    final query = _query.toLowerCase();

    String nameOf(ConversationItem c) {
      final fromServer = c.otherUser?.name ?? '';
      if (fromServer.isNotEmpty) return fromServer;
      return displayNameFor(
        ref.watch(userLookupProvider(c.getOtherParticipant(me))).value,
      );
    }

    final chats = conversations.where((c) {
      if (_deletedIds.contains(c.id)) return false;
      if (_unreadOnly && c.unreadCount == 0) return false;
      if (query.isEmpty) return true;
      return nameOf(c).toLowerCase().contains(query) ||
          c.lastMessage.toLowerCase().contains(query);
    }).toList();

    final searchingPeople = _query.length >= 2;
    final chatIds = {for (final c in conversations) c.getOtherParticipant(me)};
    // People already in the list are found under Chats.
    final people = _people.where((u) => !chatIds.contains(u.id)).toList();

    if (chats.isEmpty && !searchingPeople) {
      return _EmptyList(unreadOnly: _unreadOnly, hasQuery: query.isNotEmpty);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (searchingPeople) const _SectionLabel('Chats'),
        if (chats.isEmpty && searchingPeople)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'No chats match your search.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        for (final conv in chats)
          Dismissible(
            key: ValueKey('chat-${conv.id}'),
            direction: DismissDirection.endToStart,
            background: const _DeleteSwipeBackground(),
            confirmDismiss: (_) => _deleteConversation(conv, nameOf(conv)),
            child: _ConversationTile(
              conversation: conv,
              name: nameOf(conv),
              isTyping: typing.contains(conv.getOtherParticipant(me)),
              fallbackPhoto: conv.otherUser == null
                  ? ref
                            .watch(
                              userLookupProvider(conv.getOtherParticipant(me)),
                            )
                            .value
                            ?.profileImage ??
                        ''
                  : '',
              onTap: () => _openConversation(
                conv,
                conv.getOtherParticipant(me),
                nameOf(conv),
              ),
              onLongPress: () => _onConversationLongPress(conv, nameOf(conv)),
            ),
          ),
        if (searchingPeople) ...[
          const _SectionLabel('People on KaamMilega'),
          if (_searchingPeople)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (_peopleError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Could not search people.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _searchPeople(_query),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'No other people match "$_query".',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final user in people)
              _PersonTile(user: user, onTap: () => _messagePerson(user)),
        ],
      ],
    );
  }
}

/// "All Chats | Unread" switch.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onChanged,
  });

  final bool unreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'All Chats',
              selected: !unreadOnly,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Unread',
              count: unreadCount,
              selected: unreadOnly,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.white : Colors.transparent,
        elevation: selected ? 1 : 0,
        shadowColor: AppColors.brandNavy.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? AppColors.brandNavy
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    _CountPill(count),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// Round photo (or initial on navy) with a green dot when online.
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.name,
    required this.photo,
    this.online = false,
  });

  final String name;
  final String photo;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        photo.startsWith('http://') || photo.startsWith('https://');
    final trimmed = name.trim();
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.brandNavy,
            foregroundImage: hasPhoto ? NetworkImage(photo) : null,
            onForegroundImageError: hasPhoto ? (_, _) {} : null,
            child: Text(
              trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.name,
    required this.fallbackPhoto,
    required this.onTap,
    this.onLongPress,
    this.isTyping = false,
  });

  final ConversationItem conversation;
  final String name;
  final String fallbackPhoto;
  final VoidCallback onTap;

  /// Opens the delete option.
  final VoidCallback? onLongPress;

  /// The other person is typing right now (shown instead of the last
  /// message).
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final partner = conversation.otherUser;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;
    final online = partner?.isOnline ?? false;
    final time = conversation.formattedTime;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '$name${online ? ', online' : ''}'
          '${isTyping ? ', typing' : ''}'
          '${hasUnread ? ', $unread unread' : ''}'
          '${conversation.lastMessage.isNotEmpty ? ', ${conversation.lastMessage}' : ''}'
          '${time.isNotEmpty ? ', $time' : ''}',
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : 'Delete chat',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _ChatAvatar(
                name: name,
                photo: partner?.profileImage.isNotEmpty == true
                    ? partner!.profileImage
                    : fallbackPhoto,
                online: online,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: hasUnread
                                  ? AppColors.blue
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: isTyping
                              ? const Text(
                                  'typing...',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                )
                              : Text(
                                  conversation.lastMessage.isNotEmpty
                                      ? conversation.lastMessage
                                      : 'No messages yet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: hasUnread
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          _CountPill(unread),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red "Delete" shown behind a chat while it is swiped left.
class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.white),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Delete',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.user, required this.onTap});

  final UserProfile user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = displayNameFor(user);
    // Only the person's real headline; nothing made up when it is empty.
    final subtitle = user.headline.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _ChatAvatar(name: name, photo: user.profileImage),
            const SizedBox(width: 14),
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
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: AppColors.blue,
              semanticLabel: 'Message',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.unreadOnly, required this.hasQuery});

  final bool unreadOnly;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final (title, message) = unreadOnly
        ? ("You're all caught up", 'No unread messages.')
        : hasQuery
        ? ('No matching chats', 'Type at least 2 letters to find people.')
        : ('No conversations yet', 'Search for people above to start a chat.');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      children: [
        const Icon(
          Icons.chat_bubble_outline_rounded,
          size: 44,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            ShimmerBox(width: 52, height: 52, borderRadius: 26),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 16, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
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
