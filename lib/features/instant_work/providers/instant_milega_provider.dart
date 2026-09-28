import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nearby_professional.dart';
import '../repositories/nearby_professionals_repository.dart';
import '../services/location_service.dart';

/// Where the device location stands on the Instant Milega screen.
enum LocationStatus {
  locating,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

/// Where the nearby-professionals list stands. Kept separate from the
/// location so "no location", "backend not ready", "no results" and
/// "request failed" are never shown as the same empty state.
enum ProfessionalsStatus {
  /// No location yet, nothing requested.
  waitingForLocation,
  loading,

  /// The backend has no nearby-professionals API yet.
  backendPending,

  /// The API answered with no professionals.
  empty,
  loaded,
  error,
}

@immutable
class InstantMilegaState {
  const InstantMilegaState({
    this.locationStatus = LocationStatus.locating,
    this.location,
    this.categoryId = InstantServiceCategory.allId,
    this.professionalsStatus = ProfessionalsStatus.waitingForLocation,
    this.professionals = const [],
    this.error,
    this.selectedProfessionalId,
  });

  final LocationStatus locationStatus;
  final DeviceLocation? location;
  final String categoryId;
  final ProfessionalsStatus professionalsStatus;
  final List<NearbyProfessional> professionals;

  /// The failure behind [ProfessionalsStatus.error].
  final Object? error;

  /// Professional picked on the map (preview card); null = none.
  final String? selectedProfessionalId;

  NearbyProfessional? get selectedProfessional {
    final id = selectedProfessionalId;
    if (id == null) return null;
    for (final p in professionals) {
      if (p.id == id) return p;
    }
    return null;
  }

  InstantMilegaState copyWith({
    LocationStatus? locationStatus,
    DeviceLocation? location,
    String? categoryId,
    ProfessionalsStatus? professionalsStatus,
    List<NearbyProfessional>? professionals,
    Object? error,
    bool clearError = false,
    String? selectedProfessionalId,
    bool clearSelection = false,
  }) {
    return InstantMilegaState(
      locationStatus: locationStatus ?? this.locationStatus,
      location: location ?? this.location,
      categoryId: categoryId ?? this.categoryId,
      professionalsStatus: professionalsStatus ?? this.professionalsStatus,
      professionals: professionals ?? this.professionals,
      error: clearError ? null : (error ?? this.error),
      selectedProfessionalId: clearSelection
          ? null
          : (selectedProfessionalId ?? this.selectedProfessionalId),
    );
  }
}

/// Instant Milega screen state: one location reading when the screen opens
/// (or on Retry), then the nearby professionals for it.
class InstantMilegaNotifier extends Notifier<InstantMilegaState> {
  int _locateRun = 0;
  int _loadRun = 0;

  @override
  InstantMilegaState build() => const InstantMilegaState();

  /// Reads the device location (asks for permission the first time).
  Future<void> locate() async {
    final run = ++_locateRun;
    state = state.copyWith(locationStatus: LocationStatus.locating);
    final result = await ref.read(locationServiceProvider).currentLocation();
    if (!ref.mounted || run != _locateRun) return;
    switch (result) {
      case LocationFound(:final location):
        state = state.copyWith(
          locationStatus: LocationStatus.ready,
          location: location,
        );
        await loadProfessionals();
      case LocationFailed(:final reason):
        state = state.copyWith(
          locationStatus: switch (reason) {
            LocationFailure.serviceDisabled => LocationStatus.serviceDisabled,
            LocationFailure.permissionDenied => LocationStatus.permissionDenied,
            LocationFailure.permissionDeniedForever =>
              LocationStatus.permissionDeniedForever,
            LocationFailure.unavailable => LocationStatus.unavailable,
          },
          professionalsStatus: ProfessionalsStatus.waitingForLocation,
          professionals: const [],
          clearError: true,
          clearSelection: true,
        );
    }
  }

  /// Loads professionals near the current location (no-op without one).
  Future<void> loadProfessionals() async {
    final location = state.location;
    if (location == null || state.locationStatus != LocationStatus.ready) {
      return;
    }
    final run = ++_loadRun;
    state = state.copyWith(
      professionalsStatus: ProfessionalsStatus.loading,
      clearError: true,
    );
    final category = state.categoryId;
    try {
      final result = await ref
          .read(nearbyProfessionalsRepositoryProvider)
          .findNearby(
            NearbyProfessionalsQuery(
              location: GeoPoint(location.latitude, location.longitude),
              categoryId: category == InstantServiceCategory.allId
                  ? null
                  : category,
            ),
          );
      if (!ref.mounted || run != _loadRun) return;
      state = state.copyWith(
        professionalsStatus: result.isEmpty
            ? ProfessionalsStatus.empty
            : ProfessionalsStatus.loaded,
        professionals: result,
        clearSelection: true,
      );
    } on NearbyProfessionalsNotAvailable {
      if (!ref.mounted || run != _loadRun) return;
      state = state.copyWith(
        professionalsStatus: ProfessionalsStatus.backendPending,
        professionals: const [],
        clearSelection: true,
      );
    } catch (e) {
      if (!ref.mounted || run != _loadRun) return;
      state = state.copyWith(
        professionalsStatus: ProfessionalsStatus.error,
        professionals: const [],
        error: e,
        clearSelection: true,
      );
    }
  }

  void selectCategory(String categoryId) {
    if (categoryId == state.categoryId) return;
    state = state.copyWith(categoryId: categoryId, clearSelection: true);
    loadProfessionals();
  }

  /// Marker tap (future): shows that professional's preview card.
  void selectProfessional(String? id) {
    state = id == null
        ? state.copyWith(clearSelection: true)
        : state.copyWith(selectedProfessionalId: id);
  }
}

/// Lives while the Instant Milega screen is open (location is read again
/// the next time it opens).
final instantMilegaProvider =
    NotifierProvider.autoDispose<InstantMilegaNotifier, InstantMilegaState>(
      InstantMilegaNotifier.new,
    );
