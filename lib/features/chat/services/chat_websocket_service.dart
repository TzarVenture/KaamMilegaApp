import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/local_storage.dart';
import '../models/chat_message.dart';

enum WebSocketStatus { disconnected, connecting, connected, error }

/// Production-ready Real-Time Chat WebSocket Service with network resilience
class ChatWebSocketService {
  WebSocket? _webSocket;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  final _statusController = StreamController<WebSocketStatus>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final Set<String> _processedMessageIds = {};

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  bool _isDisposed = false;
  StreamSubscription<NetworkStatus>? _networkSubscription;

  ChatWebSocketService() {
    // Listen to network status to auto-reconnect when internet returns
    _networkSubscription = ConnectivityService().statusStream.listen((
      netStatus,
    ) {
      if (netStatus == NetworkStatus.online &&
          _status != WebSocketStatus.connected &&
          !_isDisposed) {
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        connect();
      }
    });
  }

  WebSocketStatus get status => _status;
  Stream<WebSocketStatus> get statusStream => _statusController.stream;
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Connect to km-backend WebSocket server: /api/ws/chats?token=jwt_token
  Future<void> connect() async {
    if (_isDisposed || _status == WebSocketStatus.connected) return;

    if (!ConnectivityService().isOnline) {
      _setStatus(WebSocketStatus.disconnected);
      return;
    }

    final token = LocalStorage.getToken();
    if (token == null || token.isEmpty) {
      _setStatus(WebSocketStatus.disconnected);
      return;
    }

    _setStatus(WebSocketStatus.connecting);

    try {
      // Build ws:// or wss:// URL from ApiConstants.baseUrl
      final uri = Uri.parse(ApiConstants.baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl =
          '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/api/ws/chats?token=$token';

      _webSocket?.close();
      _webSocket = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 8));
      _setStatus(WebSocketStatus.connected);
      _reconnectAttempts = 0;

      _webSocket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[ChatWebSocketService] Connection failed: $e');
      _setStatus(WebSocketStatus.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic rawData) {
    try {
      if (rawData is String) {
        final Map<String, dynamic> data = jsonDecode(rawData);
        final String type = data['type']?.toString() ?? '';

        if (type == 'NEW_MESSAGE' && data['message'] is Map<String, dynamic>) {
          final message = ChatMessage.fromJson(
            data['message'] as Map<String, dynamic>,
          );
          if (message.id.isNotEmpty &&
              !_processedMessageIds.contains(message.id)) {
            _processedMessageIds.add(message.id);
            _messageController.add(message);
          }
        }
      }
    } catch (_) {}
  }

  void _onError(dynamic error) {
    debugPrint('[ChatWebSocketService] Socket error: $error');
    _setStatus(WebSocketStatus.error);
    _scheduleReconnect();
  }

  void _onDone() {
    _setStatus(WebSocketStatus.disconnected);
    if (!_isDisposed && ConnectivityService().isOnline) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed ||
        _reconnectAttempts >= _maxReconnectAttempts ||
        !ConnectivityService().isOnline) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds =
        _reconnectAttempts * 2; // Exponential backoff (2s, 4s, 6s...)

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _status != WebSocketStatus.connected) {
        connect();
      }
    });
  }

  void _setStatus(WebSocketStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// Disconnect and cleanup resources
  void dispose() {
    _isDisposed = true;
    _networkSubscription?.cancel();
    _reconnectTimer?.cancel();
    _webSocket?.close();
    _statusController.close();
    _messageController.close();
  }
}

final chatWebSocketServiceProvider = Provider<ChatWebSocketService>((ref) {
  final service = ChatWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});
