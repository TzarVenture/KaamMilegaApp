import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_request.dart';
import '../repositories/network_repository.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';

/// Provider for list of pending incoming connection invitations
/// (Rebuilt on logout / account switch; no request without a session.)
final pendingInvitationsProvider = FutureProvider<List<ConnectionRequestItem>>((
  ref,
) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <ConnectionRequestItem>[];
  }
  return ref.watch(networkRepositoryProvider).getPendingInvitations();
});

/// Home "Connect Just Like You": up to 8 people, never the signed-in user
/// (same as the website). Works for guests too; rebuilt on login / logout.
final communityUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final me = ref.watch(sessionUserIdProvider);
  final users = await ref.watch(networkRepositoryProvider).getCommunityUsers();
  return users.where((u) => u.id.isNotEmpty && u.id != me).take(8).toList();
});

/// My Network "People You May Know": every public member
/// (GET /community/users), never the signed-in user.
final networkSuggestionsProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
      final me = ref.watch(sessionUserIdProvider);
      final users = await ref
          .watch(networkRepositoryProvider)
          .getCommunityUsers();
      return users.where((u) => u.id.isNotEmpty && u.id != me).toList();
    });

/// Another member's profile for the member profile screen. Loaded fresh
/// each time the screen opens; rebuilt on login / logout.
final memberProfileProvider = FutureProvider.autoDispose
    .family<UserProfile, String>((ref, userId) {
      ref.watch(sessionUserIdProvider);
      return ref.watch(networkRepositoryProvider).getMemberProfile(userId);
    });

/// Home "Connect With Our Experts": up to 10 experts, never the signed-in
/// user. Works for guests too; rebuilt on login / logout.
final featuredExpertsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final me = ref.watch(sessionUserIdProvider);
  final experts = await ref.watch(networkRepositoryProvider).getExperts();
  return experts.where((u) => u.id.isNotEmpty && u.id != me).take(10).toList();
});

/// Provider for list of candidate's active connection user IDs
/// (Rebuilt on logout / account switch; no request without a session.)
/// Who viewed the signed-in user's profile (profile Analytics).
final profileViewersProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) {
  if (ref.watch(sessionUserIdProvider) == null) return const <UserProfile>[];
  return ref.watch(networkRepositoryProvider).getProfileViewers();
});

final connectionsProvider = FutureProvider<List<String>>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return const <String>[];
  return ref.watch(networkRepositoryProvider).getConnections();
});

/// Family provider for checking connection status with a specific user ID
final connectionStatusProvider = FutureProvider.family<String, String>((
  ref,
  otherUserId,
) {
  // Status is between the signed-in user and [otherUserId]: rebuilt on
  // logout / account switch; no request without a session.
  if (ref.watch(sessionUserIdProvider) == null) return '';
  return ref.watch(networkRepositoryProvider).getConnectionStatus(otherUserId);
});
