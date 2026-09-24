import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cities/presentation/city_selector_sheet.dart';
import '../../features/jobs/providers/jobs_provider.dart';
import '../../features/notifications/providers/notification_provider.dart';

/// Reusable top header for category screens matching KaamMilega design:
/// - Logo (or category logo) on left with tap to navigate Home
/// - Search, Notification Bell with badge, and Hamburger Drawer option on right
/// - Location selector dropdown
/// - Search input bar
class CategoryTopHeader extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Color themeColor;
  final String? customLogoTitle;
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchSubmitted;
  final VoidCallback? onSearchIconTap;

  const CategoryTopHeader({
    super.key,
    required this.scaffoldKey,
    required this.themeColor,
    this.customLogoTitle,
    required this.searchHint,
    required this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchIconTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsState = ref.watch(jobsProvider);
    final currentCity = jobsState.filter.city.isNotEmpty
        ? jobsState.filter.city
        : 'Delhi, India';
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP ROW: LOGO + (SEARCH, NOTIFICATIONS, DRAWER)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo: Clickable navigating to Home
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/home'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child:
                        customLogoTitle != null &&
                            customLogoTitle == 'Instantmilega™'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Instant',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'milega™',
                                      style: TextStyle(
                                        color: Color(0xFFEA580C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                'assets/images/logo_text.png',
                                height: 16,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Right Action Buttons: Search, Notifications, Hamburger Drawer
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Icon Button
                  IconButton(
                    onPressed: onSearchIconTap,
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF1E293B),
                      size: 24,
                    ),
                    splashRadius: 22,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),

                  // Notification Bell with dynamic unread indicator dot
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF1E293B),
                            size: 24,
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Three-line Hamburger Drawer Button
                  IconButton(
                    onPressed: () {
                      scaffoldKey.currentState?.openEndDrawer();
                    },
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF1E293B),
                      size: 24,
                    ),
                    splashRadius: 22,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 2. LOCATION SELECTOR
          GestureDetector(
            onTap: () {
              CitySelectorSheet.show(
                context,
                currentCity: currentCity,
                onSelected: (selectedCity) {
                  ref.read(jobsProvider.notifier).setCity(selectedCity);
                },
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded, color: themeColor, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                  currentCity,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF0F172A),
                  size: 18,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. SEARCH INPUT BAR (Matching reference image)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              onSubmitted: (_) => onSearchSubmitted?.call(),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: themeColor,
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
