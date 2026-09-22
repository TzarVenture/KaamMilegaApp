import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'network_status.dart';

/// Centralized service for tracking device network connectivity across the app.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  /// Factory for testing with mock connectivity
  @visibleForTesting
  factory ConnectivityService.forTest(Connectivity connectivity) {
    return ConnectivityService._internal(connectivity: connectivity);
  }

  final Connectivity _connectivity;
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;
  bool _isOverridden = false;

  /// Current network status
  NetworkStatus get currentStatus => _currentStatus;

  /// Quick boolean helper
  bool get isOnline => _currentStatus == NetworkStatus.online;

  /// Stream of network status updates
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  void _init() {
    if (_isInitialized) return;
    _isInitialized = true;

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!_isOverridden) {
        _updateFromResults(results);
      }
    });

    // Check initial state
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!_isOverridden) {
        _updateFromResults(results);
      }
    } catch (e) {
      debugPrint(
        '[ConnectivityService] Error checking initial connectivity: $e',
      );
    }
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    final hasNoConnection =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);

    final newStatus = hasNoConnection
        ? NetworkStatus.offline
        : NetworkStatus.online;

    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  /// Manually update status (e.g. from ApiClient error or test)
  void updateStatus(NetworkStatus status) {
    _isOverridden = true;
    _currentStatus = status;
    _statusController.add(_currentStatus);
  }

  /// Clear any manual override
  void clearOverride() {
    _isOverridden = false;
    _checkInitialConnectivity();
  }

  /// On-demand active internet probe without continuous polling
  Future<bool> probeInternet() async {
    _isOverridden = false;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none)) {
        updateStatus(NetworkStatus.offline);
        return false;
      }

      // Quick DNS lookup verification
      final lookup = await InternetAddress.lookup('kaammilega.com')
          .timeout(const Duration(seconds: 3));
      final reachable = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      updateStatus(reachable ? NetworkStatus.online : NetworkStatus.offline);
      return reachable;
    } catch (_) {
      try {
        // Fallback DNS check
        final lookup = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        final reachable = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
        updateStatus(reachable ? NetworkStatus.online : NetworkStatus.offline);
        return reachable;
      } catch (_) {
        updateStatus(NetworkStatus.offline);
        return false;
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
