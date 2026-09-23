import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final asyncNotifs = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (isAuthenticated)
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read.'),
                  ),
                );
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Jobs', 'My Posts'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primaryLight,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Notifications ListView or Guest Prompt
          Expanded(
            child: !isAuthenticated
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Sign in to view notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Get real-time job alerts, application updates, and network notifications by signing in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: () => context.push('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(notificationsProvider.notifier).refresh(),
                    child: asyncNotifs.when(
                      data: (items) {
                        final filteredItems = items.where((item) {
                          if (_selectedFilter == 'Jobs') {
                            return item.type == 'job_alert' ||
                                item.type == 'application';
                          } else if (_selectedFilter == 'My Posts') {
                            return item.type == 'reaction';
                          }
                          return true;
                        }).toList();

                        if (filteredItems.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No notifications found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: filteredItems.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildNotificationTile(item);
                          },
                        );
                      },
                      loading: () => ListView.builder(
                        itemCount: 4,
                        itemBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.all(16),
                          child: ShimmerBox(width: double.infinity, height: 70),
                        ),
                      ),
                      error: (err, stack) => NetworkStateView(
                        isOffline: err is AppNetworkException,
                        errorMessage: err is AppNotFoundException
                            ? 'Notifications are coming soon.'
                            : err.toString(),
                        onRetry: () =>
                            ref.read(notificationsProvider.notifier).refresh(),
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem item) {
    final avatarUrl = ApiConstants.resolveImageUrl(item.avatarUrl);
    final hasAvatar =
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    return InkWell(
      onTap: () {
        ref.read(notificationsProvider.notifier).markAsRead(item.id);
        if (item.targetRoute.isNotEmpty) {
          context.push(item.targetRoute);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: item.isRead ? Colors.white : const Color(0xFFF7F2FA),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar or Icon badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.heroBg,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  onBackgroundImageError: hasAvatar ? (_, _) {} : null,
                  child: !hasAvatar
                      ? Icon(
                          _getIconForType(item.type),
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForType(item.type),
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.isRead
                          ? FontWeight.w700
                          : FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: item.isRead
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Unread Indicator Dot
            if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'connection':
        return Icons.people_rounded;
      case 'profile_view':
        return Icons.remove_red_eye_rounded;
      case 'application':
        return Icons.assignment_turned_in_rounded;
      case 'reaction':
        return Icons.thumb_up_rounded;
      case 'job_alert':
      default:
        return Icons.work_rounded;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
