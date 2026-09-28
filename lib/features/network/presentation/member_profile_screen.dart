import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/network_provider.dart';
import 'widgets/connect_button.dart';

/// Another member's profile (GET /user/:id), opened from "Connect Just Like
/// You" on Home. Shows only what the member shared publicly; contact details
/// (mobile, email) are never shown.
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(memberProfileProvider(userId));
    final title = profileAsync.asData?.value.name.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title.isNotEmpty ? title : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: profileAsync.when(
        data: (user) => RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(memberProfileProvider(userId).future),
          child: _ProfileBody(user: user),
        ),
        loading: () => const ShimmerLoadingList(count: 4, itemHeight: 120),
        error: (err, _) => _ErrorBody(
          error: err,
          onRetry: () => ref.invalidate(memberProfileProvider(userId)),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // The backend answers 403 for private profiles and 404 for unknown ones.
    final isPrivate =
        error is AppAuthException &&
        (error as AppAuthException).statusCode == 403;
    if (isPrivate || error is AppNotFoundException) {
      return NetworkStateView(
        isEmpty: true,
        emptyTitle: isPrivate ? 'This profile is private' : 'Profile not found',
        emptyMessage: isPrivate
            ? 'This member has chosen to keep their profile private.'
            : 'This member may have left KaamMilega.',
        child: const SizedBox.shrink(),
      );
    }
    return NetworkStateView.fromError(error, onRetry: onRetry);
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.user});

  final UserProfile user;

  String get _name => user.name.trim().isNotEmpty ? user.name.trim() : 'Member';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = ref.watch(sessionUserIdProvider) == user.id;
    // Only the server's Open To values: never text saved on this device.
    final openToWork = user.openToWorkPreferences?.isOpen ?? false;
    final providing = user.providingServicesPreferences?.isProviding ?? false;
    final about = user.about.trim();
    final skills = user.skills.where((s) => s.trim().isNotEmpty).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Header(user: user, name: _name),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (openToWork || providing)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (openToWork)
                      const _Badge(
                        label: 'Open to work',
                        color: AppColors.success,
                      ),
                    if (providing)
                      const _Badge(
                        label: 'Providing services',
                        color: AppColors.blue,
                      ),
                  ],
                ),
              if (!isMe) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ConnectButton(
                        userId: user.id,
                        name: _name,
                        height: 44,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => chatWithMember(
                          context,
                          ref,
                          userId: user.id,
                          name: _name,
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (about.isNotEmpty)
          _SectionCard(
            title: 'About',
            child: Text(
              about,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        if (skills.isNotEmpty)
          _SectionCard(
            title: 'Skills',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in skills)
                  Chip(
                    label: Text(s),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.primaryLight,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
        if (user.experience.isNotEmpty)
          _SectionCard(
            title: 'Experience',
            child: Column(
              children: [
                for (final e in user.experience)
                  _EntryTile(
                    icon: Icons.work_outline_rounded,
                    title: e.title,
                    subtitle: [
                      e.companyName,
                      e.employmentType,
                    ].where((v) => v.trim().isNotEmpty).join(' · '),
                    meta: [
                      _range(e.startDate, e.endDate),
                      e.location,
                    ].where((v) => v.trim().isNotEmpty).join(' · '),
                    description: e.description,
                  ),
              ],
            ),
          ),
        if (user.education.isNotEmpty)
          _SectionCard(
            title: 'Education',
            child: Column(
              children: [
                for (final e in user.education)
                  _EntryTile(
                    icon: Icons.school_outlined,
                    title: e.schoolName,
                    subtitle: [
                      e.degree,
                      e.fieldOfStudy,
                    ].where((v) => v.trim().isNotEmpty).join(', '),
                    meta: _range(e.startDate, e.endDate),
                    description: e.description,
                  ),
              ],
            ),
          ),
        if (user.projects.isNotEmpty)
          _SectionCard(
            title: 'Projects',
            child: Column(
              children: [
                for (final p in user.projects)
                  _EntryTile(
                    icon: Icons.folder_outlined,
                    title: p.title,
                    subtitle: p.associatedWith,
                    meta: _range(
                      p.startDate,
                      p.isCurrentlyWorking ? 'Present' : p.endDate,
                    ),
                    description: p.description,
                    link: p.link,
                  ),
              ],
            ),
          ),
        if (about.isEmpty &&
            skills.isEmpty &&
            user.experience.isEmpty &&
            user.education.isEmpty &&
            user.projects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This member has not added profile details yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  static String _range(String start, String end) {
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    if (start.isEmpty) return end;
    return '$start – $end';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.name});

  final UserProfile user;
  final String name;

  @override
  Widget build(BuildContext context) {
    final headline = user.headline.trim();
    final place = [
      user.city.trim(),
      user.state.trim(),
    ].where((v) => v.isNotEmpty).join(', ');

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryGradientStart,
                      AppColors.primaryGradientEnd,
                    ],
                  ),
                  image: user.coverImage.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(user.coverImage),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        )
                      : null,
                ),
              ),
              Positioned(
                left: 16,
                bottom: -40,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: user.profileImage.isNotEmpty
                        ? NetworkImage(user.profileImage)
                        : null,
                    onBackgroundImageError: user.profileImage.isNotEmpty
                        ? (_, _) {}
                        : null,
                    child: user.profileImage.isEmpty
                        ? Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (headline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.meta = '',
    this.description = '',
    this.link = '',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final String description;
  final String link;

  Future<void> _openLink(BuildContext context) async {
    final raw = link.trim();
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open the link: $raw')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.trim().isNotEmpty ? title.trim() : 'Untitled',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (meta.trim().isNotEmpty)
                  Text(
                    meta.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                if (link.trim().isNotEmpty)
                  TextButton(
                    onPressed: () => _openLink(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Show project'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
