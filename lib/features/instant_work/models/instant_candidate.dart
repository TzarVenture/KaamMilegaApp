import 'package:intl/intl.dart';

/// InstantPass terms, as fixed in the backend (instant_work service:
/// ₹99, 10 gig claims, 30 days). The backend has no endpoint that returns
/// them before a purchase, so they are shown from here.
class InstantPassTerms {
  InstantPassTerms._();

  static const double priceInr = 99;
  static const int gigs = 10;
  static const int validityDays = 30;

  static String get priceLabel => '₹${priceInr.toStringAsFixed(0)}';

  /// "₹9.90"
  static String get perGigLabel => '₹${(priceInr / gigs).toStringAsFixed(2)}';
}

/// The signed-in user's InstantMilega state
/// (GET /instant-work/candidate/status).
class InstantCandidateStatus {
  final bool isOnline; // is_free_now
  final String activeSkill;
  final double hourlyRate;
  final int quotaRemaining;
  final bool hasActivePass;
  final DateTime? passExpiresAt;

  /// Last position the server has for this worker (latitude, longitude),
  /// or null when it has none.
  final ({double lat, double lng})? lastLocation;

  const InstantCandidateStatus({
    this.isOnline = false,
    this.activeSkill = '',
    this.hourlyRate = 0,
    this.quotaRemaining = 0,
    this.hasActivePass = false,
    this.passExpiresAt,
    this.lastLocation,
  });

  factory InstantCandidateStatus.fromJson(Map<String, dynamic> json) {
    ({double lat, double lng})? location;
    final loc = json['current_location'];
    if (loc is Map && loc['coordinates'] is List) {
      final c = loc['coordinates'] as List;
      // GeoJSON order: [longitude, latitude]
      if (c.length == 2 && c[0] is num && c[1] is num) {
        location = (
          lat: (c[1] as num).toDouble(),
          lng: (c[0] as num).toDouble(),
        );
      }
    }
    return InstantCandidateStatus(
      isOnline: json['is_free_now'] == true,
      activeSkill: json['active_skill']?.toString().trim() ?? '',
      hourlyRate: json['hourly_rate'] is num
          ? (json['hourly_rate'] as num).toDouble()
          : 0,
      quotaRemaining: json['quota_remaining'] is num
          ? (json['quota_remaining'] as num).toInt()
          : 0,
      hasActivePass: json['has_active_pass'] == true,
      passExpiresAt: json['pass_expires_at'] == null
          ? null
          : DateTime.tryParse(json['pass_expires_at'].toString())?.toLocal(),
      lastLocation: location,
    );
  }

  /// A pass with gigs left: needed to go online.
  bool get canGoOnline => hasActivePass && quotaRemaining > 0;

  /// "12 Oct", or empty.
  String get passExpiresLabel =>
      passExpiresAt == null ? '' : DateFormat('d MMM').format(passExpiresAt!);

  InstantCandidateStatus copyWith({bool? isOnline, String? activeSkill}) =>
      InstantCandidateStatus(
        isOnline: isOnline ?? this.isOnline,
        activeSkill: activeSkill ?? this.activeSkill,
        hourlyRate: hourlyRate,
        quotaRemaining: quotaRemaining,
        hasActivePass: hasActivePass,
        passExpiresAt: passExpiresAt,
        lastLocation: lastLocation,
      );
}
