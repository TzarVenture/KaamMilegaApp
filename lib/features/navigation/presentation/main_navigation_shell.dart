import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../applications/presentation/my_applications_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../jobs/presentation/jobs_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Main navigation shell holding the 4 primary tabs: Home, Jobs, Applied, Profile
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  void _navigateToTab(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _navigateToTab),
      const JobsScreen(),
      const MyApplicationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: AppColors.primaryLight,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded, color: AppColors.primary),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(
              Icons.bookmark_rounded,
              color: AppColors.primary,
            ),
            label: 'Applied',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
