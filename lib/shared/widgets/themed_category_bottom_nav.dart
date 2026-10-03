import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../features/chat/providers/chat_provider.dart';
import 'app_bottom_nav.dart';

/// Reusable themed bottom navigation bar for KaamMilega category modules.
/// Colors and highlights adapt dynamically based on the active category theme.
class ThemedCategoryBottomNav extends ConsumerWidget {
  final Color activeColor;
  final Color secondaryColor;
  final int activeIndex;
  final String categoryLabel;
  final IconData categoryIcon;
  final VoidCallback? onCenterTap;
  final VoidCallback? onCategoryTap;

  const ThemedCategoryBottomNav({
    super.key,
    required this.activeColor,
    required this.secondaryColor,
    this.activeIndex = 1,
    required this.categoryLabel,
    required this.categoryIcon,
    this.onCenterTap,
    this.onCategoryTap,
  });

  void _showDefaultQuickActionSheet(BuildContext context) {
    final categoryName = categoryLabel;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Quick Actions • $categoryName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, color: activeColor),
                ),
                title: Text(
                  'Post or Request $categoryName',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Instant listing in $categoryName module'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$categoryName action initiated!'),
                      backgroundColor: activeColor,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Color(0xFF16A34A),
                  ),
                ),
                title: const Text(
                  'Explore All Modules',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('View all 7 KaamMilega ecosystems'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/explore');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.blue,
                  ),
                ),
                title: const Text(
                  'Upcoming Events',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Join career webinars & hiring fairs'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/events');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kept as before: the bar listens to the conversations list (the
    // chats API has no unread counts yet, so no badge is shown).
    ref.watch(conversationsProvider);

    return AppBottomNav.frame(
      children: [
        // 1. HOME TAB
        AppBottomNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          selected: activeIndex == 0,
          legacyActiveColor: activeColor,
          onTap: () => context.go('/home'),
        ),

        // 2. CATEGORY TAB
        AppBottomNavItem(
          icon: categoryIcon,
          label: categoryLabel,
          selected: activeIndex == 1,
          legacyActiveColor: activeColor,
          onTap: onCategoryTap ?? () {},
        ),

        // 3. CENTER (+) BUTTON: quick actions
        AppNavCenterButton(
          onTap: onCenterTap ?? () => _showDefaultQuickActionSheet(context),
          legacy: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),

        // 4. CHATS TAB
        AppBottomNavItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Chats',
          selected: activeIndex == 3,
          legacyActiveColor: activeColor,
          onTap: () => context.go('/chats'),
        ),

        // 5. PROFILE TAB
        AppBottomNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          selected: activeIndex == 4,
          legacyActiveColor: activeColor,
          onTap: () => context.go('/profile'),
        ),
      ],
    );
  }
}
