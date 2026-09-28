import 'package:flutter/material.dart';

/// A point on the map (latitude / longitude in degrees).
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// A professional near the user, as the Instant Milega UI needs it.
///
/// FRONTEND CONTRACT ONLY: km-backend has no nearby-professionals API yet,
/// so there is no JSON parsing here and no response format is assumed.
/// When the backend endpoint exists, add the mapping from its real response
/// (in the repository) and adjust these fields to match it. Optional fields
/// are null when the backend does not provide them; the UI then hides them
/// instead of showing invented values.
@immutable
class NearbyProfessional {
  const NearbyProfessional({
    required this.id,
    required this.name,
    required this.service,
    required this.location,
    this.photoUrl = '',
    this.categoryId,
    this.distanceKm,
    this.rating,
    this.reviewCount,
    this.isAvailable,
    this.price,
    this.priceUnit,
    this.description = '',
  });

  final String id;
  final String name;

  /// Profession / service shown under the name, e.g. "Electrician".
  final String service;
  final GeoPoint location;
  final String photoUrl;

  /// Matches [InstantServiceCategory.id] when the backend provides it.
  final String? categoryId;
  final double? distanceKm;
  final double? rating;
  final int? reviewCount;

  /// True = available now, false = busy, null = unknown.
  final bool? isAvailable;

  /// Price in INR (null = not provided).
  final double? price;

  /// What [price] is for, e.g. "hour" or "visit".
  final String? priceUnit;
  final String description;

  /// "850 m" / "1.2 km", or null when no distance is known.
  String? get distanceLabel {
    final d = distanceKm;
    if (d == null || d < 0) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  /// "₹300 / hour", "₹300", or null when no price is known.
  String? get priceLabel {
    final p = price;
    if (p == null || p < 0) return null;
    final amount = p == p.roundToDouble()
        ? p.toInt().toString()
        : p.toStringAsFixed(2);
    final unit = priceUnit?.trim() ?? '';
    return unit.isEmpty ? '₹$amount' : '₹$amount / $unit';
  }
}

/// Service categories shown as filter chips on Instant Milega.
///
/// UI constants using the product's existing service terms (Home "Popular
/// Categories" and the Services screen). The backend has no service
/// category list yet; replace this with backend data when it exists.
@immutable
class InstantServiceCategory {
  const InstantServiceCategory(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;

  static const String allId = 'all';

  static const List<InstantServiceCategory> values = [
    InstantServiceCategory(allId, 'All', Icons.apps_rounded),
    InstantServiceCategory(
      'electrician',
      'Electrician',
      Icons.electric_bolt_rounded,
    ),
    InstantServiceCategory('ac_repair', 'AC Repair', Icons.ac_unit_rounded),
    InstantServiceCategory('plumbing', 'Plumbing', Icons.plumbing_rounded),
    InstantServiceCategory(
      'house_cleaning',
      'House Cleaning',
      Icons.cleaning_services_rounded,
    ),
    InstantServiceCategory(
      'delivery',
      'Delivery',
      Icons.local_shipping_outlined,
    ),
    InstantServiceCategory('driver', 'Driver', Icons.directions_car_outlined),
  ];
}
