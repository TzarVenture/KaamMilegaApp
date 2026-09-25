import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/connection_request.dart';
import '../../../core/network/response_list.dart';
import '../../../core/network/app_exception.dart';

/// Repository handling Candidate Network & Connection APIs
class NetworkRepository {
  final ApiClient _client;

  NetworkRepository(this._client);

  /// Send a connection invitation to another user
  Future<void> sendInvitation(String receiverId) async {
    await _client.post(
      ApiConstants.networkConnect,
      data: {'receiver_id': receiverId},
    );
  }

  /// Accept an incoming connection invitation
  Future<void> acceptInvitation(String senderId) async {
    await _client.post(
      ApiConstants.networkAccept,
      data: {'sender_id': senderId},
    );
  }

  /// Ignore/Decline an incoming connection invitation
  Future<void> ignoreInvitation(String senderId) async {
    await _client.post(
      ApiConstants.networkIgnore,
      data: {'sender_id': senderId},
    );
  }

  /// Fetch list of incoming pending connection invitations
  /// Throws on failure so the screen can show an error, not "no requests".
  Future<List<ConnectionRequestItem>> getPendingInvitations() async {
    final response = await _client.get(ApiConstants.networkPending);
    return readListResponse(response.data)
        .map(ConnectionRequestItem.fromJson)
        .toList();
  }

  /// Fetch list of connected user IDs
  /// Throws on failure so the screen can show an error, not "no connections".
  Future<List<String>> getConnections() async {
    final response = await _client.get(ApiConstants.networkConnections);
    return readRawListResponse(
      response.data,
      keys: const ['connections', 'data'],
    ).map((e) => e.toString()).toList();
  }

  /// Check connection status with a specific user
  /// Throws on failure, so an unknown status is not shown as "not
  /// connected".
  Future<String> getConnectionStatus(String otherUserId) async {
    final response = await _client.get(
      '${ApiConstants.networkStatus}$otherUserId',
    );
    final data = response.data;
    if (data is Map) return data['status']?.toString() ?? '';
    throw const AppValidationException(
      'Unexpected response from server. Please try again.',
    );
  }

  /// Remove/Delete an existing connection
  Future<void> deleteConnection(String otherUserId) async {
    await _client.delete('${ApiConstants.networkDelete}$otherUserId');
  }
}

final networkRepositoryProvider = Provider<NetworkRepository>((ref) {
  return NetworkRepository(ref.watch(apiClientProvider));
});
