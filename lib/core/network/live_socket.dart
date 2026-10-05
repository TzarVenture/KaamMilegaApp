import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_constants.dart';
import '../storage/local_storage.dart';
import 'connectivity_service.dart';
import 'network_status.dart';

enum WebSocketStatus { disconnected, connecting, connected, error }

/// Opens a socket to [url] and completes once it is open. Replaceable in
/// tests.
typedef WebSocketConnector = Future<WebSocketChannel> Function(String url);

/// A live connection to one of km-backend's WebSocket hubs
/// (`GET /api/ws/...?token=JWT`). Subclasses say which [path] to open and
/// what to do with each JSON event ([handleEvent]).
///
/// Reliability rules:
/// - one socket per service at a time; callbacks from an old socket are
///   ignored;
/// - a ping every [pingInterval] keeps idle connections alive through
///   proxies and detects dead ones;
/// - reconnects forever with backoff (1s, 2s, 4s ... 30s) while online, and
///   immediately when the network comes back or [retryNow] is called;
/// - [reconnected] fires after a reconnect so screens can fetch what
///   happened while the socket was down (the server does not queue events).
abstract class LiveSocket {
  LiveSocket({
    required this.path,
    required this.logTag,
    this.connector,
    this.pingInterval = const Duration(seconds: 20),
    this.connectTimeout = const Duration(seconds: 10),
    Stream<NetworkStatus>? networkStatus,
    bool Function()? isOnline,
  }) : _isOnline = isOnline ?? (() => ConnectivityService().isOnline) {
    _networkSubscription = (networkStatus ?? ConnectivityService().statusStream)
        .listen((net) {
          if (net == NetworkStatus.online) retryNow();
        });
  }

  /// Socket path under the API base URL, for example `/ws/chats`.
  final String path;

  /// Prefix for debug logs.
  final String logTag;

  /// Opens the socket; null uses [_defaultConnect] (tests pass their own).
  final WebSocketConnector? connector;
  final bool Function() _isOnline;
  final Duration pingInterval;
  final Duration connectTimeout;

  /// A socket that stayed open this long counts as a good connection, so
  /// the backoff starts again from the shortest delay. A socket the server
  /// closes straight away (for example a rejected token) does not.
  static const Duration _stableAfter = Duration(seconds: 10);
  static const Duration _maxBackoff = Duration(seconds: 30);

  WebSocketChannel? _socket;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  final _statusController = StreamController<WebSocketStatus>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();

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
  bool get isDisposed => _isDisposed;

  /// Fires each time the socket comes back after having been connected.
  Stream<void> get reconnected => _reconnectedController.stream;

  /// ws(s)://host[:port]/api[path]?token=... built from [baseUrl].
  static String urlFor(String baseUrl, String path, String token) {
    final base = Uri.parse(baseUrl);
    return base
        .replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '${base.path}$path',
          queryParameters: {'token': token},
        )
        .toString();
  }

  /// One decoded JSON object from the server.
  @protected
  void handleEvent(Map<String, dynamic> data);

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
      final url = urlFor(ApiConstants.baseUrl, path, token);
      final socket = await (connector ?? _defaultConnect)(url)
          .timeout(connectTimeout);
      if (_isDisposed || generation != _generation) {
        unawaited(socket.sink.close());
        return;
      }
      _socket = socket;
      _openedAt = DateTime.now();
      socket.stream.listen(
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
      debugPrint('[$logTag] Connection failed: $e');
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

  /// Sends one JSON event to the server. False when not connected (the
  /// event is dropped; callers send only short-lived signals like typing).
  bool send(Map<String, dynamic> data) {
    final socket = _socket;
    if (_isDisposed || socket == null || _status != WebSocketStatus.connected) {
      return false;
    }
    try {
      socket.sink.add(jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint('[$logTag] Send failed: $e');
      return false;
    }
  }

  void _onMessage(dynamic rawData) {
    if (rawData is! String) return;
    try {
      final data = jsonDecode(rawData);
      if (data is Map<String, dynamic>) handleEvent(data);
    } catch (e) {
      debugPrint('[$logTag] Bad payload: $e');
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
      debugPrint('[$logTag] Socket error: $error');
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
    if (old != null) unawaited(old.sink.close());
  }

  /// Browser WebSocket on the web; `dart:io` socket with a keep-alive ping
  /// on phones and desktop.
  Future<WebSocketChannel> _defaultConnect(String url) async {
    final uri = Uri.parse(url);
    final channel = kIsWeb
        ? WebSocketChannel.connect(uri)
        : IOWebSocketChannel.connect(uri, pingInterval: pingInterval);
    try {
      await channel.ready;
    } catch (_) {
      unawaited(channel.sink.close());
      rethrow;
    }
    return channel;
  }

  void _setStatus(WebSocketStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    if (!_statusController.isClosed) _statusController.add(newStatus);
  }

  /// Disconnect and clean up. Subclasses close their own streams and then
  /// call `super.dispose()`.
  @mustCallSuper
  void dispose() {
    _isDisposed = true;
    _generation++;
    _networkSubscription?.cancel();
    _reconnectTimer?.cancel();
    _dropSocket();
    _statusController.close();
    _reconnectedController.close();
  }
}
