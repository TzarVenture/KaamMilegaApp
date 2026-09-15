import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_request.dart';
import '../repositories/network_repository.dart';

/// Provider for list of pending incoming connection invitations
final pendingInvitationsProvider = FutureProvider<List<ConnectionRequestItem>>((
  ref,
) {
  return ref.watch(networkRepositoryProvider).getPendingInvitations();
});

/// Provider for list of candidate's active connection user IDs
final connectionsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(networkRepositoryProvider).getConnections();
});

/// Family provider for checking connection status with a specific user ID
final connectionStatusProvider = FutureProvider.family<String, String>((
  ref,
  otherUserId,
) {
  return ref.watch(networkRepositoryProvider).getConnectionStatus(otherUserId);
});
