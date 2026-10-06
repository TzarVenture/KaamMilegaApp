import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/models/user_profile.dart';
import '../../chat/providers/user_lookup_provider.dart';
import '../../experts/providers/expert_dashboard_provider.dart';
import '../../home/presentation/widgets/connect_like_you_section.dart'
    show PersonAvatar;
import '../../peer_to_peer/presentation/widgets/people_suggestion_grid.dart';
import '../models/connection_request.dart';
import '../providers/network_provider.dart';
import '../repositories/network_repository.dart';
import 'widgets/connect_button.dart';

/// My Network, laid out like the website's network page for phones:
/// Grow Network (People You May Know, Verified Experts, Networking Events,
/// Become a Verified Mentor), Connections and Invitations.
class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key, this.initialTab = growTab});

  static const int growTab = 0;
  static const int connectionsTab = 1;

  /// Connection requests sent to me (`/network?tab=pending`, opened from a
  /// connection request notification).
  static const int invitationsTab = 2;

  final int initialTab;

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 2),
  );

  /// People hidden with X on this visit (like the website; not saved).
  final Set<String> _dismissed = {};

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  Future<void> _handleAccept(String senderId, String name) async {
    try {
      await ref.read(networkRepositoryProvider).acceptInvitation(senderId);
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(connectionsProvider);
      // Connect / Pending / Message buttons elsewhere show the new state.
      ref.invalidate(connectionStatusProvider(senderId));
      _snack('You are now connected with $name.');
    } catch (e) {
      _snack(NetworkStateView.errorMessageFor(e), error: true);
    }
  }

  Future<void> _handleIgnore(String senderId) async {
    try {
      await ref.read(networkRepositoryProvider).ignoreInvitation(senderId);
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(connectionStatusProvider(senderId));
      _snack('Invitation ignored.');
    } catch (e) {
      _snack(NetworkStateView.errorMessageFor(e), error: true);
    }
  }

  Future<void> _handleDeleteConnection(String otherId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove connection?'),
        content: Text('$name will be removed from your connections.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(networkRepositoryProvider).deleteConnection(otherId);
      ref.invalidate(connectionsProvider);
      ref.invalidate(connectionStatusProvider(otherId));
      _snack('Connection removed.');
    } catch (e) {
      _snack(NetworkStateView.errorMessageFor(e), error: true);
    }
  }

  void _openMember(String id) => context.push('/members/$id');

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider).value;
    final invitations = ref.watch(pendingInvitationsProvider).value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'My Network',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Messages',
            // Switch to the Chats tab instead of opening a second copy of
            // the main screen on top of this one.
            onPressed: () => context.go('/chats'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          tabs: [
            const Tab(text: 'Grow Network'),
            _CountTab(label: 'Connections', count: connections?.length),
            _CountTab(label: 'Invitations', count: invitations?.length),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGrowTab(connections ?? const []),
          _buildConnectionsTab(),
          _buildInvitationsTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grow Network
  // ---------------------------------------------------------------------------

  Widget _buildGrowTab(List<String> connectionIds) {
    final suggestionsAsync = ref.watch(networkSuggestionsProvider);
    final isExpert = ref.watch(isExpertProvider);
    final connected = connectionIds.toSet();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(networkSuggestionsProvider);
        ref.invalidate(connectionsProvider);
        ref.invalidate(connectionStatusProvider);
        try {
          await ref.read(networkSuggestionsProvider.future);
        } catch (_) {
          // Shown on the page.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ExploreLinks(
            onExperts: () => context.push('/experts'),
            onEvents: () => context.push('/events'),
          ),
          const SizedBox(height: 20),
          _PeopleHeader(
            connectionCount: connectionIds.length,
            onViewConnections: () =>
                _tabController.animateTo(NetworkScreen.connectionsTab),
          ),
          const SizedBox(height: 14),
          suggestionsAsync.when(
            data: (all) {
              final people = all
                  .where(
                    (u) =>
                        !_dismissed.contains(u.id) && !connected.contains(u.id),
                  )
                  .toList();
              if (people.isEmpty) {
                return const _InlineMessage(
                  icon: Icons.group_outlined,
                  title: 'No suggestions right now',
                  message:
                      'Check back later to find more people to connect with.',
                );
              }
              return PeopleSuggestionGrid(
                users: people,
                onOpen: (u) => _openMember(u.id),
                onDismiss: (u) => setState(() => _dismissed.add(u.id)),
              );
            },
            loading: () => const _GridSkeleton(),
            error: (e, _) => _InlineMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load people',
              message: NetworkStateView.errorMessageFor(e),
              onRetry: () => ref.invalidate(networkSuggestionsProvider),
            ),
          ),
          if (!isExpert) ...[
            const SizedBox(height: 12),
            _MentorPromo(
              onApply: () => AuthGuard.openProtected(context, '/apply-expert'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Connections
  // ---------------------------------------------------------------------------

  Widget _buildConnectionsTab() {
    final connectionsAsync = ref.watch(connectionsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(connectionsProvider);
        try {
          await ref.read(connectionsProvider.future);
        } catch (_) {
          // Shown on the page.
        }
      },
      child: connectionsAsync.when(
        data: (ids) {
          if (ids.isEmpty) {
            return _EmptyTab(
              icon: Icons.people_outline_rounded,
              title: 'No connections yet',
              message: 'Connect with people in Grow Network. Accepted requests show here.',
              actionLabel: 'Find people',
              onAction: () => _tabController.animateTo(NetworkScreen.growTab),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: _MemberRow(
                userId: ids[index],
                onOpen: () => _openMember(ids[index]),
                actionsBuilder: (name) => [
                  ConnectButton(
                    userId: ids[index],
                    name: name,
                    height: 36,
                    fontSize: 12.5,
                    messageWhenConnected: true,
                    showIcon: true,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options for $name',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (_) =>
                        _handleDeleteConnection(ids[index], name),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove connection'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const _ListSkeleton(),
        error: (err, _) => NetworkStateView.fromError(
          err,
          onRetry: () => ref.invalidate(connectionsProvider),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Invitations
  // ---------------------------------------------------------------------------

  Widget _buildInvitationsTab() {
    final pendingAsync = ref.watch(pendingInvitationsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(pendingInvitationsProvider);
        try {
          await ref.read(pendingInvitationsProvider.future);
        } catch (_) {
          // Shown on the page.
        }
      },
      child: pendingAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const _EmptyTab(
              icon: Icons.mark_email_read_outlined,
              title: 'No pending invitations',
              message: 'Connection requests sent to you will show here.',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ConnectionRequestItem req = requests[index];
              return FadeSlideIn(
                index: index,
                child: _MemberRow(
                  userId: req.senderId,
                  note: 'Wants to connect with you',
                  onOpen: () => _openMember(req.senderId),
                  stackedActions: true,
                  actionsBuilder: (name) => [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleIgnore(req.senderId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Ignore',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAccept(req.senderId, name),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const _ListSkeleton(),
        error: (err, _) => NetworkStateView.fromError(
          err,
          onRetry: () => ref.invalidate(pendingInvitationsProvider),
        ),
      ),
    );
  }
}

/// Tab label with a small count (hidden until the count is known).
class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final n = count;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (n != null && n > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Verified Experts and Networking Events, as on the website's side menu.
class _ExploreLinks extends StatelessWidget {
  const _ExploreLinks({required this.onExperts, required this.onEvents});

  final VoidCallback onExperts;
  final VoidCallback onEvents;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LinkTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Verified Experts',
            onTap: onExperts,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LinkTile(
            icon: Icons.event_outlined,
            label: 'Networking Events',
            onTap: onEvents,
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "People You May Know", its description and "View Connections (N)".
class _PeopleHeader extends StatelessWidget {
  const _PeopleHeader({
    required this.connectionCount,
    required this.onViewConnections,
  });

  final int connectionCount;
  final VoidCallback onViewConnections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'People You May Know',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onViewConnections,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                'View Connections ($connectionCount)',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const Text(
          'Expand your network across industry peers and career mentors',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Navy "Become a Verified Mentor" card with an orange Apply Now button.
class _MentorPromo extends StatelessWidget {
  const _MentorPromo({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'EXPERT NETWORK',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Become a Verified Mentor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Guide ambitious candidates, host 1-on-1 calls, and monetize your '
            'professional experience.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              elevation: 0,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Apply Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One member in Connections / Invitations: photo, name and what they do
/// from GET /user/:id ("Unknown user" when the profile cannot be read,
/// e.g. it is private), then the actions.
class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.userId,
    required this.onOpen,
    required this.actionsBuilder,
    this.note = '',
    this.stackedActions = false,
  });

  final String userId;
  final VoidCallback onOpen;

  /// Built with the member's display name.
  final List<Widget> Function(String name) actionsBuilder;

  /// Extra line, e.g. "Wants to connect with you".
  final String note;

  /// Actions on their own row under the name (Accept / Ignore).
  final bool stackedActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(userLookupProvider(userId));
    final user = lookup.value;
    final loading = lookup.isLoading && user == null;
    final name = displayNameFor(user);
    final details = [
      user?.headline.trim() ?? '',
      user?.city.trim() ?? '',
    ].where((v) => v.isNotEmpty).join(' · ');

    final info = Expanded(
      child: loading
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 14, borderRadius: 6),
                SizedBox(height: 6),
                ShimmerBox(width: 160, height: 11, borderRadius: 6),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ],
            ),
    );

    final avatar = ExcludeSemantics(
      child: PersonAvatar(
        user: user ?? UserProfile(id: userId, mobile: ''),
        size: 48,
      ),
    );

    final actions = actionsBuilder(name);
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onOpen,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: stackedActions
              ? Column(
                  children: [
                    Row(children: [avatar, const SizedBox(width: 12), info]),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(children: actions),
                    ),
                  ],
                )
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    info,
                    const SizedBox(width: 8),
                    ...actions,
                  ],
                ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primaryLight,
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < 2; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  const Expanded(
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 220,
                      borderRadius: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const ShimmerBox(
        width: double.infinity,
        height: 76,
        borderRadius: 14,
      ),
    );
  }
}
