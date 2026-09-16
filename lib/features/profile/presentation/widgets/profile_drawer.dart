import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

/// Navigation Drawer matching KaamMilega web profile side menu
class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  static void open(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }

  void _launchExpertUrl(BuildContext context) async {
    final uri = Uri.parse('https://kaammilega.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening KaamMilega™ Expert Registration...'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName = user?.name.isNotEmpty == true ? user!.name : 'Suny verma';
    final userHeadline =
        user?.headline.isNotEmpty == true ? user!.headline : 'User';
    final userAvatar = user?.profileImage ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Row(
                      children: [
                        // Logo / Profile Avatar
                        Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            color: Color(0xFF320058),
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: userAvatar.isNotEmpty
                                ? Image.network(
                                    userAvatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const _DefaultAvatarIcon(),
                                  )
                                : const _DefaultAvatarIcon(),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userHeadline,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // View Profile Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/profile');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8E24AA),
                          side: const BorderSide(
                            color: Color(0xFF8E24AA),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'View Profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 16),

                    // 1. Account Section
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DrawerMenuItem(
                      title: 'Try Premium',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'KaamMilega™ Premium Membership coming soon!',
                            ),
                          ),
                        );
                      },
                    ),
                    _DrawerMenuItem(
                      title: 'Setting & Privacy',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/settings');
                      },
                    ),
                    _DrawerMenuItem(
                      title: 'Help',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'KaamMilega™ 24/7 Support Helpline: 1800 123 456',
                            ),
                          ),
                        );
                      },
                    ),
                    _DrawerMenuItem(
                      title: 'Language',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/settings');
                      },
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 16),

                    // 2. Manage Section
                    const Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DrawerMenuItem(
                      title: 'Posts & Activity',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/feed');
                      },
                    ),
                    _DrawerMenuItem(
                      title: 'Job Posting Account',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/jobs');
                      },
                    ),
                    _DrawerMenuItem(
                      title: 'Applied Jobs Status',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/my-applications');
                      },
                    ),
                    _DrawerMenuItem(
                      title: 'Interviews',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/interviews');
                      },
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 16),

                    // 3. Sign Out Action
                    _DrawerMenuItem(
                      title: 'Sign Out',
                      textColor: const Color(0xFF6B7280),
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // 4. Bottom Redirect Link: Apply to be an Expert ↗
                    // (NOTE: Create Company Page omitted as explicitly requested)
                    InkWell(
                      onTap: () => _launchExpertUrl(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: const [
                            Text(
                              'Apply to be an Expert',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF8E24AA),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.north_east_rounded,
                              size: 15,
                              color: Color(0xFF8E24AA),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _DefaultAvatarIcon extends StatelessWidget {
  const _DefaultAvatarIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person_rounded, color: Colors.white, size: 30);
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color textColor;

  const _DrawerMenuItem({
    required this.title,
    required this.onTap,
    this.textColor = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
