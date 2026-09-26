import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../../../shared/widgets/category_top_header.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/themed_category_bottom_nav.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/open_chat.dart';
import '../../network/models/connection_request.dart';
import '../../network/providers/network_provider.dart';
import '../../network/repositories/network_repository.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../app/theme/app_colors.dart';

class PeerToPeerScreen extends ConsumerStatefulWidget {
  const PeerToPeerScreen({super.key});

  @override
  ConsumerState<PeerToPeerScreen> createState() => _PeerToPeerScreenState();
}

class _PeerToPeerScreenState extends ConsumerState<PeerToPeerScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<UserProfile> _discoveredUsers = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchUsers('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get(
        ApiConstants.userSearch,
        queryParameters: {if (query.isNotEmpty) 'q': query, 'limit': 20},
      );

      if (response.data is List) {
        final list = (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map(UserProfile.fromJson)
            .toList();

        // Filter out current logged in user
        final currentUserId = ref.read(authProvider).user?.id;
        final filtered = list.where((u) => u.id != currentUserId).toList();

        setState(() {
          _discoveredUsers = filtered;
          _isSearching = false;
          _searchError = null;
        });
        return;
      }
      setState(() {
        _discoveredUsers = [];
        _isSearching = false;
        _searchError = null;
      });
    } catch (e) {
      final errorMsg = e is AppNotFoundException
          ? 'User discovery is currently under development.'
          : (e is AppNetworkException
                ? 'No internet connection. Please check your network.'
                : 'Could not load users. Please try again.');
      setState(() {
        _discoveredUsers = [];
        _isSearching = false;
        _searchError = errorMsg;
      });
    }
  }

  Future<void> _handleConnect(String userId) async {
    try {
      await ref.read(networkRepositoryProvider).sendInvitation(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection invitation sent!'),
          backgroundColor: AppColors.moduleP2P,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send invitation: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleAccept(String senderId) async {
    try {
      await ref.read(networkRepositoryProvider).acceptInvitation(senderId);
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(connectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection request accepted!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingInvitationsProvider);
    final connectionsAsync = ref.watch(connectionsProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: const ThemedCategoryBottomNav(
        activeColor: AppColors.moduleP2P,
        secondaryColor: AppColors.brandNavy,
        categoryLabel: 'Network',
        categoryIcon: Icons.people_rounded,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CategoryTopHeader(
              showSearchIcon: false, // search bar below is enough
              scaffoldKey: _scaffoldKey,
              themeColor: AppColors.moduleP2P,
              searchHint: 'Search network peers & workers...',
              searchController: _searchController,
              onSearchChanged: _searchUsers,
              onSearchSubmitted: () => _searchUsers(_searchController.text),
            ),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.moduleP2P,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.moduleP2P,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Discover'),
                  Tab(text: 'Connections'),
                  Tab(text: 'Requests'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Discover Peers Tab
                  _buildDiscoverTab(),

                  // 2. Active Connections Tab
                  _buildConnectionsTab(connectionsAsync),

                  // 3. Pending Requests Tab
                  _buildPendingTab(pendingAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Purple Hero Banner (IMAGE 2)
        _buildHeroBanner(),

        const SizedBox(height: 16),

        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            onSubmitted: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Search people by name, profession or skill...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.moduleP2P,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'People You May Know',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ShimmerLoadingList(count: 3, itemHeight: 90),
          )
        else if (_searchError != null)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.moduleP2PLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    size: 32,
                    color: AppColors.moduleP2P,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'User Discovery Unavailable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _searchUsers(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.moduleP2P,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (_discoveredUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 36,
                  color: AppColors.moduleP2P,
                ),
                SizedBox(height: 12),
                Text(
                  'No users found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Try searching for other professions, cities or skills.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._discoveredUsers.map((u) => _buildUserCard(u)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandNavy, AppColors.moduleP2P],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.moduleP2P.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PEER-TO-PEER COLLABORATION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connect, share & grow\ntogether.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Expand your network with peers, verified workers & colleagues.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.moduleP2PLight,
            backgroundImage: user.profileImage.isNotEmpty
                ? NetworkImage(user.profileImage)
                : null,
            child: user.profileImage.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.moduleP2P,
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
                  user.name.isNotEmpty ? user.name : 'KaamMilega User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (user.headline.isNotEmpty)
                  Text(
                    user.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (user.city.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          user.city,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleConnect(user.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moduleP2P,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'Connect',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab(AsyncValue<List<String>> connectionsAsync) {
    return connectionsAsync.when(
      data: (connections) {
        if (connections.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 40,
                    color: AppColors.moduleP2P,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No connections yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Switch to the Discover tab to connect with peers in your industry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: connections.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: Builder(
              builder: (context) {
                final connId = connections[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.moduleP2PLight,
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.moduleP2P,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connected Colleague',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'ID: $connId',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.moduleP2P,
                        ),
                        onPressed: () => openChatWithUser(
                          context,
                          ref,
                          receiverId: connId,
                          title: 'Chat',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ShimmerLoadingList(count: 4, itemHeight: 80),
      ),
      error: (e, _) => NetworkStateView.fromError(
        e,
        onRetry: () => ref.invalidate(connectionsProvider),
      ),
    );
  }

  Widget _buildPendingTab(
    AsyncValue<List<ConnectionRequestItem>> pendingAsync,
  ) {
    return pendingAsync.when(
      data: (pending) {
        if (pending.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 40,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No pending invitations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Incoming connection requests from other candidates will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: Builder(
              builder: (context) {
                final item = pending[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.moduleP2PLight,
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: AppColors.moduleP2P,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User #${item.senderId.substring(0, item.senderId.length > 8 ? 8 : item.senderId.length)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              'Wants to connect with you',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _handleAccept(item.senderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: ShimmerLoadingList(count: 3, itemHeight: 80),
      ),
      error: (e, _) => NetworkStateView.fromError(
        e,
        onRetry: () => ref.invalidate(pendingInvitationsProvider),
      ),
    );
  }
}
