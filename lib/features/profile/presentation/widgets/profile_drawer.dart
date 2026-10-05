import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../experts/providers/expert_dashboard_provider.dart';
import '../../../../shared/widgets/notification_bell_button.dart';

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
                              // Same bell button as the headers; closes the
                              // drawer first.
                              NotificationBellButton(
                                color: const Color(0xFF334155),
                                size: 22,
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.push('/notifications');
                                },
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
                        AuthGuard.openProtected(context, '/network');
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
                        context.push('/experts');
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
                    _DrawerIconTile(
                      icon: Icons.apps_rounded,
                      title: 'Explore All Modules',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/explore');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.account_balance_wallet_outlined,
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
                      title: 'Setting & Privacy',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/settings');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & FAQ',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/help');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Applied Jobs Status',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/my-applications');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.video_call_outlined,
                      title: 'Interviews',
                      onTap: () {
                        Navigator.pop(context);
                        AuthGuard.openProtected(context, '/interviews');
                      },
                    ),
                    _DrawerIconTile(
                      icon: Icons.co_present_outlined,
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
                        title: 'Expert Dashboard',
                        onTap: () {
                          Navigator.pop(context);
                          AuthGuard.openProtected(context, '/expert-dashboard');
                        },
                      ),
                    _DrawerIconTile(
                      icon: Icons.confirmation_number_outlined,
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

/// One drawer row: a plain icon (no background box) and the title.
/// Icons share one calm grey so the list reads as a simple menu; rows with
/// a meaning colour (Sign Out red, Sign In navy) use it for the icon too.
class _DrawerIconTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color textColor;

  const _DrawerIconTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = textColor == AppColors.textPrimary
        ? AppColors.textSecondary
        : textColor;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // 48px tall rows: comfortable to tap
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
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
