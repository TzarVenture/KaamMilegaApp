import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../feed/presentation/create_post_modal.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../jobs/presentation/jobs_screen.dart';
import '../../network/presentation/network_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/providers/notification_provider.dart';

/// Full KaamMilega™ 5-Tab Navigation Shell
class MainNavigationShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final screens = [
      const FeedScreen(),
      const NetworkScreen(),
      const SizedBox.shrink(), // Index 2 reserved for Post (+) modal trigger
      const NotificationsScreen(),
      const JobsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: AppColors.primaryLight,
        onDestinationSelected: (index) {
          if (index == 2) {
            // Center Post (+) action trigger
            CreatePostModal.show(context);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: AppColors.primary),
            label: 'My Network',
          ),
          NavigationDestination(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A2B8C).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Badge(
              label: unreadCount > 0 ? Text('$unreadCount') : null,
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: Badge(
              label: unreadCount > 0 ? Text('$unreadCount') : null,
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.notifications_rounded,
                color: AppColors.primary,
              ),
            ),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded, color: AppColors.primary),
            label: 'Jobs & CV',
          ),
        ],
      ),
    );
  }
}
