import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../experts/providers/expert_dashboard_provider.dart';
import '../../../notifications/providers/notification_provider.dart';

/// Unified Application Navigation Drawer matching the Home Screen design (Screenshot 1)
/// Used consistently across Home, Jobs, Chats, Apply Expert, and Profile screens.
class ProfileDrawer extends ConsumerWidget {
  final void Function(int index)? onNavigateTab;

  const ProfileDrawer({super.key, this.onNavigateTab});

  static void open(BuildContext context) {
    Scaffold.of(context).openEndDrawer();
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
                          // A photo that fails to load falls back to the
                          // person icon instead of an empty circle.
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: AppColors.navy,
                            foregroundImage: hasAvatar
                                ? NetworkImage(userAvatar)
                                : null,
                            onForegroundImageError: hasAvatar
                                ? (_, _) {}
                                : null,
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
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
                                    color: AppColors.textPrimary,
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
                                    color: AppColors.textSecondary,
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
                      color: AppColors.brandNavy,
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
                      color: AppColors.moduleP2P,
                      title: 'Network',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/network');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.calendar_today_outlined,
                      color: AppColors.moduleEvents,
                      title: 'Events',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/events');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.business_center_outlined,
                      color: AppColors.blue,
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
                      color: AppColors.moduleExperts,
                      title: 'Mentors',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/experts');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.accent,
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
                      color: AppColors.moduleSkills,
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
                    _DrawerIconTile(
                      icon: Icons.apps_rounded,
                      color: AppColors.moduleServices,
                      title: 'Explore All Modules',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/explore');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.success,
                      title: 'Digital Wallet & Ledger',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(
                          context,
                          '/wallet',
                          message: 'Please login to access your wallet.',
                        );
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.settings_outlined,
                      color: AppColors.navy,
                      title: 'Setting & Privacy',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/settings');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.help_outline_rounded,
                      color: AppColors.blue,
                      title: 'Help & FAQ',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/help');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.assignment_turned_in_outlined,
                      color: AppColors.blue,
                      title: 'Applied Jobs Status',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/my-applications');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.video_call_outlined,
                      color: AppColors.moduleP2P,
                      title: 'Interviews',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/interviews');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.co_present_outlined,
                      color: AppColors.moduleExperts,
                      title: 'My Sessions',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/my-sessions');
                      },
                    ),
                    // Only for Experts, like the website's Expert Portal
                    if (ref.watch(isExpertProvider))
                      _DrawerIconTile(
                        icon: Icons.dashboard_customize_outlined,
                        color: AppColors.moduleExperts,
                        title: 'Expert Dashboard',
                        onTap: () {
                          Navigator.pop(context);
                          AuthGuard.openProtected(context, '/expert-dashboard');
                        },
                      ),
                    _DrawerIconTile(
                      icon: Icons.confirmation_number_outlined,
                      color: AppColors.moduleEvents,
                      title: 'My Tickets',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/my-tickets');
                      },
                    ),
                    _ApplyExpertDrawerCard(
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/apply-expert');
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
                      _DrawerIconTile(
                        icon: Icons.logout_rounded,
                        color: AppColors.error,
                        title: 'Sign Out',
                        textColor: AppColors.error,
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
                      _DrawerIconTile(
                        icon: Icons.login_rounded,
                        color: AppColors.primary,
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

  /// Module colour of the icon (on a light tint of the same colour).
  final Color color;
  final Color textColor;

  const _DrawerIconTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.color,
    this.textColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Apply to be an Expert" as a highlighted orange card, so it stands out
/// from the plain menu rows.
class _ApplyExpertDrawerCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ApplyExpertDrawerCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accentBright],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apply to be an Expert',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Host paid 1-on-1 mentorship calls',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
