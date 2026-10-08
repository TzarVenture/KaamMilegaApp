import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../experts/providers/expert_dashboard_provider.dart';
import '../../../../shared/widgets/notification_bell_button.dart';

/// App menu (end drawer) used on Home, Jobs, Chats, Profile and the
/// category screens: a navy header with the brand and the user, then the
/// menu in three groups (Browse, My activity, Account) and Sign out /
/// Sign in pinned at the bottom.
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
        : (isAuth ? 'User' : 'Sign in to apply, chat and save jobs');
    final userAvatar = ApiConstants.resolveImageUrl(user?.profileImage ?? '');
    final hasAvatar =
        isAuth &&
        userAvatar.isNotEmpty &&
        (userAvatar.startsWith('http://') || userAvatar.startsWith('https://'));

    /// Closes the drawer, then opens a Home tab (or its route when the
    /// drawer is not on Home).
    void goTab(int index, String route) {
      Navigator.pop(context);
      if (onNavigateTab != null) {
        onNavigateTab!(index);
      } else {
        context.go(route);
      }
    }

    void push(String route) {
      Navigator.pop(context);
      context.push(route);
    }

    void protected(String route, {String? message}) {
      Navigator.pop(context);
      if (message == null) {
        AuthGuard.openProtected(context, route);
      } else {
        AuthGuard.openProtected(context, route, message: message);
      }
    }

    return Drawer(
      backgroundColor: AppColors.white,
      width: (MediaQuery.sizeOf(context).width * 0.8).clamp(280.0, 340.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DrawerHeader(
            userName: userName,
            userRole: userRole,
            avatarUrl: hasAvatar ? userAvatar : null,
            isAuth: isAuth,
            onLogo: () => goTab(0, '/home'),
            onNotifications: () => push('/notifications'),
            onProfile: () {
              if (isAuth) {
                goTab(4, '/profile');
              } else {
                push('/login');
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Browse'),
                  _DrawerIconTile(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    onTap: () => goTab(0, '/home'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.business_center_outlined,
                    title: 'Jobs',
                    onTap: () => goTab(1, '/jobs'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Network',
                    onTap: () => protected('/network'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Events',
                    onTap: () => push('/events'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Mentors',
                    onTap: () => push('/experts'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chat',
                    onTap: () => goTab(3, '/chats'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.library_books_outlined,
                    title: 'Resources',
                    onTap: () => push('/feed'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.apps_rounded,
                    title: 'Explore All Modules',
                    onTap: () => push('/explore'),
                  ),

                  const _SectionLabel('My activity'),
                  _DrawerIconTile(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Applied Jobs Status',
                    onTap: () => protected('/my-applications'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.video_call_outlined,
                    title: 'Interviews',
                    onTap: () => protected('/interviews'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.co_present_outlined,
                    title: 'My Sessions',
                    onTap: () => protected('/my-sessions'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'My Tickets',
                    onTap: () => protected('/my-tickets'),
                  ),
                  // Only for Experts, like the website's Expert Portal
                  if (ref.watch(isExpertProvider))
                    _DrawerIconTile(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Expert Dashboard',
                      onTap: () => protected('/expert-dashboard'),
                    ),
                  _ApplyExpertDrawerCard(
                    onTap: () => protected('/apply-expert'),
                  ),

                  const _SectionLabel('Account'),
                  _DrawerIconTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Digital Wallet & Ledger',
                    onTap: () => protected(
                      '/wallet',
                      message: 'Please login to access your wallet.',
                    ),
                  ),
                  _DrawerIconTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings & Privacy',
                    onTap: () => protected('/settings'),
                  ),
                  _DrawerIconTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & FAQ',
                    onTap: () => push('/help'),
                  ),
                ],
              ),
            ),
          ),

          // Sign out / Sign in, always in reach at the bottom.
          const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: isAuth
                  ? _FooterButton(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      color: AppColors.error,
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Signed out successfully.'),
                              backgroundColor: AppColors.brandNavy,
                            ),
                          );
                          context.go('/home');
                        }
                      },
                    )
                  : _FooterButton(
                      icon: Icons.login_rounded,
                      label: 'Sign In / Create Account',
                      color: AppColors.brandNavy,
                      filled: true,
                      onTap: () => push('/login'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Navy header: brand, notifications and close, then the user with a Profile
/// (or Sign In) button. Runs up under the status bar.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.userName,
    required this.userRole,
    required this.avatarUrl,
    required this.isAuth,
    required this.onLogo,
    required this.onNotifications,
    required this.onProfile,
  });

  final String userName;
  final String userRole;
  final String? avatarUrl;
  final bool isAuth;
  final VoidCallback onLogo;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, top + 6, 6, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandNavy, AppColors.navy],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'KaamMilega. Go to Home',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onLogo,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              'assets/images/logo_text_on_dark.webp',
                              height: 18,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Same bell as the headers; closes the drawer first.
                NotificationBellButton(
                  color: AppColors.white,
                  size: 22,
                  onPressed: onNotifications,
                ),
                IconButton(
                  tooltip: 'Close menu',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                // A photo that fails to load falls back to the person icon.
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.white.withValues(alpha: 0.15),
                    foregroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    onForegroundImageError: avatarUrl != null
                        ? (_, _) {}
                        : null,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userRole,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: AppColors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.white,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onProfile,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        isAuth ? 'Profile' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandNavy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small grey group title ("BROWSE").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// One menu row: the icon on a soft rounded tile, then the title. The
/// press highlight is rounded and inset, like the rest of the app.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // 48px tall rows: comfortable to tap
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: AppColors.brandNavy),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
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

/// Full-width Sign Out (red outline) or Sign In (navy, filled) button.
class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.white : color;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Material(
        color: filled ? color : color.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: filled
              ? BorderSide.none
              : BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
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
                            fontWeight: FontWeight.w700,
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
