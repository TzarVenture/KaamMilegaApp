import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../cities/repositories/city_repository.dart';
import '../models/connection_request.dart';

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
  Future<List<ConnectionRequestItem>> getPendingInvitations() async {
    try {
      final response = await _client.get(ApiConstants.networkPending);
      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['data'] is List) {
        list = body['data'];
      }

      return list
          .map((e) => ConnectionRequestItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch list of connected user IDs
  Future<List<String>> getConnections() async {
    try {
      final response = await _client.get(ApiConstants.networkConnections);
      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['connections'] is List) {
        list = body['connections'];
      }

      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check connection status with a specific user
  Future<String> getConnectionStatus(String otherUserId) async {
    try {
      final response = await _client.get(
        '${ApiConstants.networkStatus}$otherUserId',
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['status']?.toString() ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Remove/Delete an existing connection
  Future<void> deleteConnection(String otherUserId) async {
    await _client.delete('${ApiConstants.networkDelete}$otherUserId');
  }
}

final networkRepositoryProvider = Provider<NetworkRepository>((ref) {
  return NetworkRepository(ref.watch(apiClientProvider));
});
