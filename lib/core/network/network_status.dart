/// Network connectivity status for KaamMilega
enum NetworkStatus {
  /// Active internet access confirmed
  online,

  /// Device has no network connection or internet is unreachable
  offline,

  /// Currently probing or transitioning network status
  checking,
}

extension NetworkStatusExtension on NetworkStatus {
  bool get isOnline => this == NetworkStatus.online;
  bool get isOffline => this == NetworkStatus.offline;
  bool get isChecking => this == NetworkStatus.checking;
}
