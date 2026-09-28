import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nearby_professional.dart';

/// What the UI asks for: professionals near [location].
@immutable
class NearbyProfessionalsQuery {
  const NearbyProfessionalsQuery({
    required this.location,
    this.categoryId,
    this.radiusKm = defaultRadiusKm,
  });

  /// Radius the future API is expected to use; no radius selector yet.
  static const double defaultRadiusKm = 5;

  final GeoPoint location;

  /// Null = all categories.
  final String? categoryId;
  final double radiusKm;
}

/// The backend has no nearby-professionals API yet. Thrown by
/// [PendingNearbyProfessionalsRepository]; the UI shows a "coming soon"
/// state for it (not an error and not "no results").
class NearbyProfessionalsNotAvailable implements Exception {
  const NearbyProfessionalsNotAvailable();

  @override
  String toString() => 'Nearby professionals are not available yet.';
}

/// Source of nearby professionals for Instant Milega.
///
/// When km-backend adds the endpoint, implement this with the app's
/// ApiClient (endpoint in ApiConstants, response mapped to
/// [NearbyProfessional]) and change [nearbyProfessionalsRepositoryProvider].
/// The UI and provider do not need to change.
abstract interface class NearbyProfessionalsRepository {
  Future<List<NearbyProfessional>> findNearby(NearbyProfessionalsQuery query);
}

/// Used until the backend API exists: makes no request and returns no
/// invented data.
class PendingNearbyProfessionalsRepository
    implements NearbyProfessionalsRepository {
  const PendingNearbyProfessionalsRepository();

  @override
  Future<List<NearbyProfessional>> findNearby(
    NearbyProfessionalsQuery query,
  ) async {
    throw const NearbyProfessionalsNotAvailable();
  }
}

final nearbyProfessionalsRepositoryProvider =
    Provider<NearbyProfessionalsRepository>(
      (ref) => const PendingNearbyProfessionalsRepository(),
    );
