import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../notifications/providers/notification_provider.dart';

/// Unified Application Navigation Drawer matching the Home Screen design (Screenshot 1)
/// Used consistently across Home, Jobs, Chats, Apply Expert, and Profile screens.
class ProfileDrawer extends ConsumerWidget {
  final void Function(int index)? onNavigateTab;

  const ProfileDrawer({super.key, this.onNavigateTab});

  static void open(BuildContext context) {
    Scaffold.of(context).openEndDrawer();
  }

  void _showMentorsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF7C3AED),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Mentors & Experts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '1-on-1 career guidance & resume reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Connect with verified industry leaders from top tech and business organizations for career roadmap and mentorship sessions.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/apply-expert');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Explore Mentors & Sessions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuth = authState.isAuthenticated && authState.user != null;
    final user = authState.user;

    final userName = (isAuth && user!.name.trim().isNotEmpty)
        ? user.name.trim()
        : (isAuth ? 'Candidate' : 'Guest User');
    final userRole = (isAuth && user!.headline.trim().isNotEmpty)
        ? user.headline.trim()
        : (isAuth ? 'User' : 'Guest');
    final userAvatar = ApiConstants.resolveImageUrl(user?.profileImage ?? '');
    final hasAvatar =
        isAuth &&
        userAvatar.isNotEmpty &&
        (userAvatar.startsWith('http://') || userAvatar.startsWith('https://'));

    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Drawer(
      backgroundColor: Colors.white,
      width: (MediaQuery.of(context).size.width * 0.78).clamp(280.0, 340.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Drawer Header (Logo + Search + Notif + Close X)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                if (onNavigateTab != null) {
                                  onNavigateTab!(0);
                                } else {
                                  context.go('/home');
                                }
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/logo.png',
                                      height: 26,
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.search_rounded,
                                  size: 22,
                                  color: Color(0xFF334155),
                                ),
                                splashRadius: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (onNavigateTab != null) {
                                    onNavigateTab!(1);
                                  } else {
                                    context.go('/jobs');
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/notifications');
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.notifications_none_rounded,
                                        size: 22,
                                        color: Color(0xFF334155),
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
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 24,
                                  color: Color(0xFF334155),
                                ),
                                splashRadius: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),

                    // 2. User Profile Card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              shape: BoxShape.circle,
                              image: hasAvatar
                                  ? DecorationImage(
                                      image: NetworkImage(userAvatar),
                                      fit: BoxFit.cover,
                                      onError: (_, _) {},
                                    )
                                  : null,
                            ),
                            child: !hasAvatar
                                ? const Center(
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userRole,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (isAuth) {
                                if (onNavigateTab != null) {
                                  onNavigateTab!(4);
                                } else {
                                  context.push('/profile');
                                }
                              } else {
                                context.push('/login');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              isAuth ? 'Profile' : 'Sign In',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 6),

                    // 3. Main Nav Items with Icons (Screenshot 1)
                    _DrawerIconTile(
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () {
                        Navigator.pop(context);
                        if (onNavigateTab != null) {
                          onNavigateTab!(0);
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.people_outline_rounded,
                      title: 'Network',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/network');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Events',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/events');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.business_center_outlined,
                      title: 'Jobs',
                      onTap: () {
                        Navigator.pop(context);
                        if (onNavigateTab != null) {
                          onNavigateTab!(1);
                        } else {
                          context.go('/jobs');
                        }
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.menu_book_outlined,
                      title: 'Mentors',
                      onTap: () {
                        Navigator.pop(context);
                        _showMentorsModal(context);
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Chat',
                      onTap: () {
                        Navigator.pop(context);
                        if (onNavigateTab != null) {
                          onNavigateTab!(3);
                        } else {
                          context.go('/chats');
                        }
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.library_books_outlined,
                      title: 'Resources',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/feed');
                      },
                    ),

                    const SizedBox(height: 6),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 6),

                    // 4. Secondary Text Menu Items (Screenshot 1)
                    _DrawerTextTile(
                      title: 'Digital Wallet & Ledger',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/wallet');
                      },
                    ),
                    _DrawerTextTile(
                      title: 'Setting & Privacy',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/settings');
                      },
                    ),
                    _DrawerTextTile(
                      title: 'Applied Jobs Status',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/my-applications');
                      },
                    ),
                    _DrawerTextTile(
                      title: 'Interviews',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/interviews');
                      },
                    ),
                    _DrawerTextTile(
                      title: 'Apply to be an Expert',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/apply-expert');
                      },
                    ),

                    const SizedBox(height: 6),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 6),

                    // 5. Auth Sign Out / Sign In
                    if (isAuth)
                      _DrawerTextTile(
                        title: 'Sign Out',
                        textColor: const Color(0xFFDC2626),
                        onTap: () async {
                          Navigator.pop(context);
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signed out successfully.'),
                                backgroundColor: Color(0xFF1E293B),
                              ),
                            );
                            context.go('/home');
                          }
                        },
                      )
                    else
                      _DrawerTextTile(
                        title: 'Sign In / Create Account',
                        textColor: AppColors.primary,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/login');
                        },
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerIconTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerIconTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF334155)),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTextTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color textColor;

  const _DrawerTextTile({
    required this.title,
    required this.onTap,
    this.textColor = const Color(0xFF1E293B),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
