import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// The device's position from one location reading.
@immutable
class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// Radius of the reading's accuracy in metres (null when unknown).
  final double? accuracyMeters;
}

/// Why no location could be read.
enum LocationFailure {
  /// Location / GPS is switched off on the phone.
  serviceDisabled,

  /// The user did not allow location (can be asked again).
  permissionDenied,

  /// Location is blocked for the app; only the phone's settings can change it.
  permissionDeniedForever,

  /// The phone could not give a position (timeout, no signal, other error).
  unavailable,
}

sealed class LocationResult {
  const LocationResult();
}

final class LocationFound extends LocationResult {
  const LocationFound(this.location);
  final DeviceLocation location;
}

final class LocationFailed extends LocationResult {
  const LocationFailed(this.reason);
  final LocationFailure reason;
}

/// One-time device location (no continuous tracking), via geolocator.
///
/// Permission is asked only when [currentLocation] is called, i.e. when the
/// user opens Instant Milega; never at app start. Never throws.
class LocationService {
  const LocationService();

  Future<LocationResult> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFailed(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFailed(LocationFailure.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationFailed(LocationFailure.permissionDenied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFound(
        DeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
        ),
      );
    } on LocationServiceDisabledException {
      return const LocationFailed(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      return const LocationFailed(LocationFailure.permissionDenied);
    } catch (_) {
      // Timeout, no fix, platform error: shown as "location unavailable".
      return const LocationFailed(LocationFailure.unavailable);
    }
  }

  /// Opens this app's settings page (to allow a blocked permission).
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the phone's location (GPS) settings.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
