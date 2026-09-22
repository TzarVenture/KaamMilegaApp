import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'network_status.dart';

/// Provider for the singleton ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Riverpod notifier tracking the global NetworkStatus
class NetworkStatusNotifier extends Notifier<NetworkStatus> {
  @override
  NetworkStatus build() {
    final service = ref.watch(connectivityServiceProvider);

    // Listen to network status stream
    final sub = service.statusStream.listen((status) {
      state = status;
    });

    ref.onDispose(() {
      sub.cancel();
    });

    return service.currentStatus;
  }

  /// Manually trigger an active probe or status update
  Future<void> refresh() async {
    final service = ref.read(connectivityServiceProvider);
    await service.probeInternet();
  }
}

/// Global NetworkStatus Notifier Provider
final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, NetworkStatus>(
      NetworkStatusNotifier.new,
    );

/// Boolean provider indicating whether the device is currently online
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status == NetworkStatus.online;
});
