import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../providers/network_provider.dart';
import '../repositories/network_repository.dart';
import '../../../shared/widgets/fade_slide_in.dart';

/// Screen displaying Candidate Connections and Pending Invitations
class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept(String senderId) async {
    try {
      await ref.read(networkRepositoryProvider).acceptInvitation(senderId);
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(connectionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Connection invitation accepted!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to accept: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleIgnore(String senderId) async {
    try {
      await ref.read(networkRepositoryProvider).ignoreInvitation(senderId);
      ref.invalidate(pendingInvitationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invitation ignored')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to ignore: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteConnection(String otherId) async {
    try {
      await ref.read(networkRepositoryProvider).deleteConnection(otherId);
      ref.invalidate(connectionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Connection removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to remove connection: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => context.push('/chats'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Connections'),
            Tab(text: 'Pending Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Connections Tab
          _buildConnectionsTab(),

          // 2. Pending Requests Tab
          _buildPendingTab(),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab() {
    final connectionsAsync = ref.watch(connectionsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(connectionsProvider);
        await ref.read(connectionsProvider.future);
      },
      child: connectionsAsync.when(
        data: (connections) {
          if (connections.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: FadeSlideIn(
                      child: Column(
                        children: const [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              Icons.people_outline_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No connections yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Connect with recruiters, hiring managers, and fellow gig workers!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: connections.length,
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: Builder(
                builder: (context) {
                  final connId = connections[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          radius: 22,
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Member #${connId.substring(0, connId.length > 8 ? 8 : connId.length)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Connected candidate / professional',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: AppColors.error,
                            size: 20,
                          ),
                          tooltip: 'Remove connection',
                          onPressed: () => _handleDeleteConnection(connId),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const MyApplicationsSkeleton(),
        error: (err, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: FadeSlideIn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFFEF2F2),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load connections: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(connectionsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    final pendingAsync = ref.watch(pendingInvitationsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(pendingInvitationsProvider);
        await ref.read(pendingInvitationsProvider.future);
      },
      child: pendingAsync.when(
        data: (pendingList) {
          if (pendingList.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: FadeSlideIn(
                      child: Column(
                        children: const [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              Icons.mark_email_read_outlined,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No pending invitations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You have responded to all connection requests.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingList.length,
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: Builder(
                builder: (context) {
                  final req = pendingList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          radius: 22,
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User #${req.senderId.substring(0, req.senderId.length > 8 ? 8 : req.senderId.length)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Sent you a connection request',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.error,
                          ),
                          onPressed: () => _handleIgnore(req.senderId),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                          onPressed: () => _handleAccept(req.senderId),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const MyApplicationsSkeleton(),
        error: (err, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: FadeSlideIn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFFEF2F2),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load pending requests: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(pendingInvitationsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
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
