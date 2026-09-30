import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';

enum WebSocketStatus { disconnected, connecting, connected, error }

/// Opens a socket to [url]. Replaceable in tests.
typedef WebSocketConnector = Future<WebSocket> Function(String url);

/// Live chat socket: GET /api/ws/chats?token=JWT (km-backend chat hub).
///
/// The server only pushes `{"type":"NEW_MESSAGE","message":{...}}` events;
/// sending always goes over REST (POST /chats/messages).
///
/// Reliability rules:
/// - only one socket at a time (the server keeps one socket per user, and a
///   second socket from the same phone would knock the first one out);
/// - callbacks from an old socket are ignored;
/// - a ping every [pingInterval] keeps idle connections alive through
///   proxies and detects dead ones;
/// - reconnects forever with backoff (1s, 2s, 4s ... 30s) while online, and
///   immediately when the network comes back or [retryNow] is called;
/// - [reconnected] fires after a reconnect so open chats can fetch the
///   messages that arrived while the socket was down (the server does not
///   queue them).
class ChatWebSocketService {
  ChatWebSocketService({
    WebSocketConnector? connector,
    this.pingInterval = const Duration(seconds: 20),
    this.connectTimeout = const Duration(seconds: 10),
    Stream<NetworkStatus>? networkStatus,
    bool Function()? isOnline,
  }) : _connector = connector ?? WebSocket.connect,
       _isOnline = isOnline ?? (() => ConnectivityService().isOnline) {
    _networkSubscription = (networkStatus ?? ConnectivityService().statusStream)
        .listen((net) {
          if (net == NetworkStatus.online) retryNow();
        });
  }

  final WebSocketConnector _connector;
  final bool Function() _isOnline;
  final Duration pingInterval;
  final Duration connectTimeout;

  /// A socket that stayed open this long counts as a good connection, so
  /// the backoff starts again from the shortest delay. A socket the server
  /// closes straight away (for example a rejected token) does not.
  static const Duration _stableAfter = Duration(seconds: 10);
  static const Duration _maxBackoff = Duration(seconds: 30);

  WebSocket? _socket;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  final _statusController = StreamController<WebSocketStatus>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();
  final Set<String> _processedMessageIds = {};

  /// Identifies the current socket; events from older sockets are ignored.
  int _generation = 0;
  bool _connecting = false;
  bool _everConnected = false;
  DateTime? _openedAt;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  StreamSubscription<NetworkStatus>? _networkSubscription;

  WebSocketStatus get status => _status;
  Stream<WebSocketStatus> get statusStream => _statusController.stream;
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Fires each time the socket comes back after having been connected.
  Stream<void> get reconnected => _reconnectedController.stream;

  /// ws(s)://host[:port]/api/ws/chats?token=... built from [baseUrl].
  static String socketUrl(String baseUrl, String token) {
    final base = Uri.parse(baseUrl);
    return base
        .replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '${base.path}${ApiConstants.wsChats}',
          queryParameters: {'token': token},
        )
        .toString();
  }

  /// Connects unless already connected or connecting.
  Future<void> connect() async {
    if (_isDisposed || _connecting || _status == WebSocketStatus.connected) {
      return;
    }
    if (!_isOnline()) {
      _setStatus(WebSocketStatus.disconnected);
      return;
    }
    final token = LocalStorage.getToken();
    if (token == null || token.isEmpty) {
      _setStatus(WebSocketStatus.disconnected);
      return;
    }

    _connecting = true;
    _reconnectTimer?.cancel();
    final generation = ++_generation;
    _dropSocket();
    _setStatus(WebSocketStatus.connecting);

    try {
      final socket = await _connector(socketUrl(ApiConstants.baseUrl, token))
          .timeout(connectTimeout);
      if (_isDisposed || generation != _generation) {
        unawaited(socket.close());
        return;
      }
      socket.pingInterval = pingInterval;
      _socket = socket;
      _openedAt = DateTime.now();
      socket.listen(
        _onMessage,
        onError: (Object e) => _onClosed(generation, error: e),
        onDone: () => _onClosed(generation),
        cancelOnError: true,
      );
      _setStatus(WebSocketStatus.connected);
      if (_everConnected && !_reconnectedController.isClosed) {
        _reconnectedController.add(null);
      }
      _everConnected = true;
    } catch (e) {
      if (_isDisposed || generation != _generation) return;
      debugPrint('[ChatWebSocketService] Connection failed: $e');
      _setStatus(WebSocketStatus.error);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// Try again now (network back, app resumed, or the user tapped Retry).
  void retryNow() {
    if (_isDisposed || _connecting || _status == WebSocketStatus.connected) {
      return;
    }
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    connect();
  }

  void _onMessage(dynamic rawData) {
    if (rawData is! String) return;
    try {
      final data = jsonDecode(rawData);
      if (data is! Map<String, dynamic>) return;
      final payload = data['message'];
      if (data['type'] != 'NEW_MESSAGE' || payload is! Map<String, dynamic>) {
        return;
      }
      final message = ChatMessage.fromJson(payload);
      if (message.id.isEmpty || !_processedMessageIds.add(message.id)) return;
      if (_processedMessageIds.length > 1000) {
        _processedMessageIds.remove(_processedMessageIds.first);
      }
      if (!_messageController.isClosed) _messageController.add(message);
    } catch (e) {
      debugPrint('[ChatWebSocketService] Bad payload: $e');
    }
  }

  void _onClosed(int generation, {Object? error}) {
    if (_isDisposed || generation != _generation) return; // an old socket
    final opened = _openedAt;
    if (opened != null && DateTime.now().difference(opened) >= _stableAfter) {
      _reconnectAttempts = 0;
    }
    _socket = null;
    _openedAt = null;
    if (error != null) {
      debugPrint('[ChatWebSocketService] Socket error: $error');
    }
    _setStatus(
      error != null ? WebSocketStatus.error : WebSocketStatus.disconnected,
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed || !_isOnline()) return;
    _reconnectTimer?.cancel();
    final step = _reconnectAttempts < 5 ? _reconnectAttempts : 5;
    final seconds = 1 << step; // 1, 2, 4, 8, 16, then the 30s cap
    _reconnectAttempts++;
    final delay = Duration(seconds: seconds) > _maxBackoff
        ? _maxBackoff
        : Duration(seconds: seconds);
    _reconnectTimer = Timer(delay, connect);
  }

  void _dropSocket() {
    final old = _socket;
    _socket = null;
    _openedAt = null;
    if (old != null) unawaited(old.close());
  }

  void _setStatus(WebSocketStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    if (!_statusController.isClosed) _statusController.add(newStatus);
  }

  /// Disconnect and cleanup resources
  void dispose() {
    _isDisposed = true;
    _generation++;
    _networkSubscription?.cancel();
    _reconnectTimer?.cancel();
    _dropSocket();
    _statusController.close();
    _messageController.close();
    _reconnectedController.close();
  }
}

/// One socket per signed-in account: on logout or account switch the old
/// service is disposed (socket closed) and a new one is created, which only
/// connects when a token exists.
final chatWebSocketServiceProvider = Provider<ChatWebSocketService>((ref) {
  ref.watch(sessionUserIdProvider);
  final service = ChatWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});
