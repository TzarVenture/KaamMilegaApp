import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/login_required_view.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../models/notification_target.dart';
import '../providers/notification_provider.dart';
import 'widgets/notification_visuals.dart';

/// Categories of the screen (as on the website) and the backend category
/// each one asks for.
const _categories = <(String, String, IconData)>[
  ('All', NotificationCategory.all, Icons.notifications_rounded),
  ('Messages & Chat', NotificationCategory.messages, Icons.chat_bubble_rounded),
  ('Jobs & Applications', NotificationCategory.jobs, Icons.work_rounded),
  ('Network & Invites', NotificationCategory.network, Icons.people_rounded),
  ('System & Alerts', NotificationCategory.system, Icons.campaign_rounded),
];

/// Notifications: categories, an "Unread only" switch, a keyword filter,
/// Today / Yesterday / Earlier groups and compact rows with a quick action
/// (Reply, View, Profile ...). Everything is read from and saved to
/// km-backend `/api/notifications`.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loadMoreFailed = false;

  String get _query => _searchController.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAllRead() async {
    final ok = await ref.read(notificationsProvider.notifier).markAllAsRead();
    if (!mounted) return;
    _snack(
      ok
          ? 'All notifications marked as read.'
          : 'Could not mark notifications as read. Please try again.',
    );
  }

  Future<void> _loadMore() async {
    final ok = await ref.read(notificationsProvider.notifier).loadMore();
    if (mounted && _loadMoreFailed == ok) setState(() => _loadMoreFailed = !ok);
  }

  void _open(NotificationItem item) {
    final notifier = ref.read(notificationsProvider.notifier);
    if (!item.isRead) unawaited(notifier.markAsRead(item.id));
    final target = notificationTarget(item);
    if (target != null) openNotificationTarget(GoRouter.of(context), target);
  }

  Future<void> _markRead(NotificationItem item) async {
    final ok = await ref
        .read(notificationsProvider.notifier)
        .markAsRead(item.id);
    if (!ok && mounted) {
      _snack('Could not mark as read. Please try again.');
    }
  }

  Future<void> _delete(NotificationItem item) async {
    final ok = await ref.read(notificationsProvider.notifier).delete(item.id);
    if (!ok && mounted) {
      _snack('Could not delete the notification. Please try again.');
    }
  }

  void _selectCategory(String value) {
    setState(() => _loadMoreFailed = false);
    ref.read(notificationCategoryProvider.notifier).select(value);
  }

  void _setUnreadOnly(bool value) {
    setState(() => _loadMoreFailed = false);
    ref.read(notificationUnreadOnlyProvider.notifier).set(value);
  }

  /// Keyword filter over the loaded notifications: name, title, message,
  /// company and job title (as on the website).
  bool _matches(NotificationItem n) {
    final q = _query;
    if (q.isEmpty) return true;
    return [
      n.actorName,
      n.title,
      n.message,
      n.meta('company_name'),
      n.meta('company'),
      n.meta('job_title'),
    ].any((field) => field.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0.5,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (isAuthenticated && unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue,
                ),
              ),
            ),
          if (isAuthenticated)
            IconButton(
              tooltip: 'Notification settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(
                Icons.tune_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: !isAuthenticated
          ? const LoginRequiredView(
              title: 'Sign in to view notifications',
              message:
                  'Get application updates, messages and network '
                  'notifications by signing in.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilters(),
                Expanded(child: _buildList()),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final category = ref.watch(notificationCategoryProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    final feed = ref.watch(notificationsProvider).value;
    final label = _categories.firstWhere((c) => c.$2 == category).$1;
    final shown = feed?.items.where(_matches).length ?? 0;
    final countText = feed == null
        ? ''
        : _query.isNotEmpty
        ? '$shown of ${feed.total}'
        : '${feed.total}';

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (text, value, icon) = _categories[i];
                return _CategoryChip(
                  label: text,
                  icon: icon,
                  selected: value == category,
                  onTap: () => _selectCategory(value),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: label,
                      children: [
                        if (countText.isNotEmpty)
                          TextSpan(
                            text: '  ($countText)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  'Unread only',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Switch.adaptive(
                  value: unreadOnly,
                  activeTrackColor: AppColors.brandNavy,
                  onChanged: _setUnreadOnly,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Filter by name, company or keyword',
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
                        tooltip: 'Clear filter',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                  borderSide: const BorderSide(
                    color: AppColors.blue,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final async = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);

    return RefreshIndicator(
      color: AppColors.brandNavy,
      onRefresh: notifier.refresh,
      child: async.when(
        loading: () => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerBox(width: double.infinity, height: 60),
          ),
        ),
        error: (err, _) => NetworkStateView(
          isOffline: err is AppNetworkException,
          errorMessage: err is AppNotFoundException
              ? 'Notifications are not available yet.'
              : err.toString(),
          onRetry: notifier.refresh,
          child: const SizedBox.shrink(),
        ),
        data: (feed) {
          final items = feed.items.where(_matches).toList();
          if (items.isEmpty) {
            return _EmptyState(
              searching: _query.isNotEmpty,
              unreadOnly: unreadOnly,
              onShowAll: () => _setUnreadOnly(false),
              onClearSearch: () {
                _searchController.clear();
                setState(() {});
              },
            );
          }
          final rows = _withSections(items);
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              // The keyword filter only searches what is loaded, so more
              // pages load only when not filtering (as on the website).
              if (index == rows.length) {
                return _query.isEmpty
                    ? _footer(feed)
                    : const SizedBox(height: 8);
              }
              final row = rows[index];
              if (row is String) return _SectionHeader(row);
              final item = row as NotificationItem;
              return Dismissible(
                key: ValueKey('notification-${item.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  color: AppColors.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.white,
                  ),
                ),
                onDismissed: (_) => _delete(item),
                child: _NotificationRow(
                  item: item,
                  onTap: () => _open(item),
                  onAction: () => _open(item),
                  onMarkRead: () => _markRead(item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _footer(NotificationFeed feed) {
    if (!feed.hasMore) return const SizedBox(height: 8);
    if (_loadMoreFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() => _loadMoreFailed = false);
            _loadMore();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Could not load more. Tap to retry'),
        ),
      );
    }
    // The footer is built when the end of the list comes near: load the
    // next page.
    if (!feed.isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }

  /// Notifications with "Today", "Yesterday" and "Earlier" headers.
  static List<Object> _withSections(List<NotificationItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String section(DateTime d) {
      if (!d.isBefore(today)) return 'Today';
      if (!d.isBefore(yesterday)) return 'Yesterday';
      return 'Earlier';
    }

    final rows = <Object>[];
    String? last;
    for (final item in items) {
      final s = section(item.createdAt);
      if (s != last) {
        rows.add(s);
        last = s;
      }
      rows.add(item);
    }
    return rows;
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brandNavy : AppColors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.brandNavy : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Icon colours by category (website: messages blue, network green ...).
({Color fg, Color bg}) _categoryColors(NotificationItem item) {
  switch (item.category) {
    case NotificationCategory.messages:
      return (fg: AppColors.blue, bg: AppColors.blue.withValues(alpha: 0.12));
    case NotificationCategory.network:
      return (
        fg: AppColors.success,
        bg: AppColors.success.withValues(alpha: 0.12),
      );
    case NotificationCategory.jobs:
      return (
        fg: AppColors.brandNavy,
        bg: AppColors.brandNavy.withValues(alpha: 0.08),
      );
    default:
      return (
        fg: AppColors.accentDark,
        bg: AppColors.accent.withValues(alpha: 0.14),
      );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.item);

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final photo = item.actorAvatar;
    final hasPhoto =
        photo.startsWith('http://') || photo.startsWith('https://');
    final colors = _categoryColors(item);
    return CircleAvatar(
      radius: 22,
      backgroundColor: colors.bg,
      foregroundImage: hasPhoto ? NetworkImage(photo) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Icon(notificationIcon(item), size: 20, color: colors.fg),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.onTap,
    required this.onAction,
    required this.onMarkRead,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final name = item.actorName.isNotEmpty
        ? item.actorName
        : (item.title.isNotEmpty ? item.title : 'Notification');
    final action = notificationActionLabel(item);
    // Narrow phones: the whole row opens the same screen, so the action
    // button is left out to give the text room (as on the website).
    final roomForAction = MediaQuery.sizeOf(context).width >= 360;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: unread
            ? Color.alphaBlend(
                AppColors.blue.withValues(alpha: 0.05),
                AppColors.white,
              )
            : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                _RowIcon(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$name  ',
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.message.isNotEmpty)
                          TextSpan(
                            text: item.message,
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: unread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        TextSpan(
                          text: '  ·  ${timeAgo(item.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
                if (action != null && roomForAction) ...[
                  const SizedBox(width: 8),
                  _ActionPill(label: action, onTap: onAction),
                ],
                if (unread)
                  IconButton(
                    tooltip: 'Mark as read',
                    visualDensity: VisualDensity.compact,
                    onPressed: onMarkRead,
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blue.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34, minWidth: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandNavy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.unreadOnly,
    required this.onShowAll,
    required this.onClearSearch,
  });

  final bool searching;
  final bool unreadOnly;
  final VoidCallback onShowAll;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final (title, message) = searching
        ? (
            'No matching notifications',
            'Check the spelling or clear the filter.',
          )
        : unreadOnly
        ? ("You're all caught up!", 'No unread notifications.')
        : (
            'No notifications yet',
            'Messages, application updates and other alerts will show here.',
          );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 72),
      children: [
        Icon(
          searching ? Icons.search_rounded : Icons.notifications_none_rounded,
          size: 48,
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
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (searching || unreadOnly) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: searching ? onClearSearch : onShowAll,
              child: Text(searching ? 'Clear filter' : 'View all'),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Just now", "5m ago", "3h ago", "2d ago", then the date.
String timeAgo(DateTime dt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
