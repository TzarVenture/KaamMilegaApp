import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_request.dart';
import '../repositories/network_repository.dart';
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

/// Provider for list of candidate's active connection user IDs
/// (Rebuilt on logout / account switch; no request without a session.)
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
