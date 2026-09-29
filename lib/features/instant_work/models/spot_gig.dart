import 'package:intl/intl.dart';

/// Where a spot gig stands (backend instant_work JobStatus).
enum SpotGigStatus {
  dispatching, // open, waiting for a worker to claim it
  accepted, // claimed by a worker
  inProgress,
  completed, // worker marked it done; waiting for the employer
  closed, // employer approved; pay credited
  cancelled,
  expired,
  unknown;

  static SpotGigStatus parse(String? raw) =>
      switch ((raw ?? '').toUpperCase()) {
        'DISPATCHING' => dispatching,
        'ACCEPTED' => accepted,
        'IN_PROGRESS' => inProgress,
        'COMPLETED' => completed,
        'CLOSED' => closed,
        'CANCELLED' => cancelled,
        'EXPIRED' => expired,
        _ => unknown,
      };
}

/// An on-demand spot gig posted by an employer (backend InstantJob).
class SpotGig {
  final String id;
  final String recruiterId;
  final String recruiterName;
  final String companyName;

  /// Employer's phone. Shown only for a gig the user has claimed.
  final String recruiterMobile;
  final String skill;
  final String address;
  final double payRate;
  final String rateType; // "hourly" or "flat"
  final int durationHours;
  final int requiredWorkers;
  final String notes;
  final SpotGigStatus status;
  final double? distanceKm;
  final DateTime? expiresAt;
  final ({double lat, double lng})? location;

  const SpotGig({
    required this.id,
    this.recruiterId = '',
    this.recruiterName = '',
    this.companyName = '',
    this.recruiterMobile = '',
    this.skill = '',
    this.address = '',
    this.payRate = 0,
    this.rateType = '',
    this.durationHours = 0,
    this.requiredWorkers = 0,
    this.notes = '',
    this.status = SpotGigStatus.unknown,
    this.distanceKm,
    this.expiresAt,
    this.location,
  });

  factory SpotGig.fromJson(Map<String, dynamic> json) {
    double num0(Object? v) => v is num ? v.toDouble() : 0;
    ({double lat, double lng})? location;
    final loc = json['location'];
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
    double? distance;
    if (json['distance_km'] is num) {
      distance = (json['distance_km'] as num).toDouble();
    } else if (json['distance_meters'] is num) {
      distance = (json['distance_meters'] as num).toDouble() / 1000;
    }
    return SpotGig(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      recruiterId: json['recruiter_id']?.toString() ?? '',
      recruiterName: json['recruiter_name']?.toString().trim() ?? '',
      companyName: json['company_name']?.toString().trim() ?? '',
      recruiterMobile: json['recruiter_mobile']?.toString().trim() ?? '',
      skill: json['skill']?.toString().trim() ?? '',
      address: json['address']?.toString().trim() ?? '',
      payRate: num0(json['pay_rate']),
      rateType: json['rate_type']?.toString().toLowerCase() ?? '',
      durationHours: num0(json['duration_hours']).toInt(),
      requiredWorkers: num0(json['required_workers']).toInt(),
      notes: json['notes']?.toString().trim() ?? '',
      status: SpotGigStatus.parse(json['status']?.toString()),
      distanceKm: distance,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString())?.toLocal(),
      location: location,
    );
  }

  bool get isHourly => rateType == 'hourly';

  /// "Electrician" (the trade as posted, first letter capital).
  String get title {
    if (skill.isEmpty) return 'Spot gig';
    return '${skill[0].toUpperCase()}${skill.substring(1)}';
  }

  /// "Acme Pvt Ltd", else the employer's name.
  String get employer => companyName.isNotEmpty ? companyName : recruiterName;

  /// "₹350 / hour" or "₹1,200".
  String get payLabel {
    final amount = formatInr(payRate);
    return isHourly ? '$amount / hour' : amount;
  }

  /// Total for the gig when it can be worked out ("₹1,400 for 4 hours").
  String? get totalLabel {
    if (!isHourly || durationHours <= 0 || payRate <= 0) return null;
    return '${formatInr(payRate * durationHours)} for $durationHours '
        '${durationHours == 1 ? 'hour' : 'hours'}';
  }

  /// "1.2 km away", or null.
  String? get distanceLabel {
    final d = distanceKm;
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m away';
    return '${d.toStringAsFixed(1)} km away';
  }

  /// Minutes left to claim (open gigs close quickly), or null.
  int? minutesLeft(DateTime now) {
    final end = expiresAt;
    if (end == null) return null;
    final left = end.difference(now).inSeconds;
    if (left <= 0) return 0;
    return (left / 60).ceil();
  }

  /// The worker can still mark it done.
  bool get canComplete =>
      status == SpotGigStatus.accepted || status == SpotGigStatus.inProgress;
}

/// "₹1,400" (Indian digit grouping, no paise).
String formatInr(double amount) =>
    '₹${NumberFormat('#,##,###', 'en_IN').format(amount.round())}';
