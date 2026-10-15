import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/response_list.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/nearby_professional.dart';
import '../models/spot_gig.dart';
import 'nearby_professionals_repository.dart';

/// What the person hiring fills in for a quick job (POST
/// /instant-work/dispatch). One worker claims it: the server gives the job
/// to the first worker who accepts.
class HireRequestDraft {
  const HireRequestDraft({
    required this.skill,
    required this.address,
    required this.lat,
    required this.lng,
    required this.payRate,
    required this.hourly,
    required this.durationHours,
    this.radiusKm = 5,
    this.notes = '',
  });

  /// Trade as workers choose it (an [InstantServiceCategory] label).
  final String skill;
  final String address;
  final double lat;
  final double lng;

  /// Rupees per hour when [hourly], else the fixed price.
  final double payRate;
  final bool hourly;
  final int durationHours;
  final double radiusKm;
  final String notes;

  Map<String, dynamic> toJson() => {
    'skill': skill,
    'lat': lat,
    'lng': lng,
    'address': address.trim(),
    'radius_km': radiusKm,
    'pay_rate': payRate,
    'rate_type': hourly ? 'hourly' : 'flat',
    'duration_hours': durationHours,
    'required_workers': 1,
    'notes': notes.trim(),
  };
}

/// Instant Milega APIs for people hiring (km-backend `instant_work`
/// "recruiter" routes; any signed-in user, no pass needed).
class InstantHireRepository {
  InstantHireRepository(this._client);

  final ApiClient _client;

  /// Workers who are online ("Free Now") with pass gigs left within
  /// [radiusKm] (GET /instant-work/recruiter/radar). The server moves each
  /// pin 100-180 m for privacy, so distances are approximate. Ratings and
  /// gig counts are not used: the server fills defaults for new workers.
  Future<List<NearbyProfessional>> findWorkers({
    required double lat,
    required double lng,
    String skill = '',
    double radiusKm = 5,
  }) async {
    final trade = skill.trim();
    final response = await _client.get(
      ApiConstants.instantRadar,
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (trade.isNotEmpty && trade.toLowerCase() != 'all') 'skill': trade,
      },
    );
    return readListResponse(response.data)
        .map(_worker)
        .whereType<NearbyProfessional>()
        .toList();
  }

  static NearbyProfessional? _worker(Map<String, dynamic> json) {
    final id = (json['user_id'] ?? json['id'])?.toString() ?? '';
    if (id.isEmpty) return null;
    final loc = json['location'];
    var point = const GeoPoint(0, 0);
    if (loc is Map && loc['coordinates'] is List) {
      final c = loc['coordinates'] as List;
      if (c.length == 2 && c[0] is num && c[1] is num) {
        point = GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }
    }
    double? distance;
    if (json['distance_km'] is num) {
      distance = (json['distance_km'] as num).toDouble();
    } else if (json['distance_meters'] is num) {
      distance = (json['distance_meters'] as num).toDouble() / 1000;
    }
    final rate = json['hourly_rate'] is num
        ? (json['hourly_rate'] as num).toDouble()
        : 0.0;
    final skill = json['active_skill']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    return NearbyProfessional(
      id: id,
      name: name.isEmpty ? 'KaamMilega worker' : name,
      service: skill.isEmpty || skill.toLowerCase() == 'all'
          ? 'Any trade'
          : '${skill[0].toUpperCase()}${skill.substring(1)}',
      location: point,
      photoUrl: ApiConstants.resolveImageUrl(json['avatar']?.toString() ?? ''),
      distanceKm: distance,
      // The radar returns only workers who are online now.
      isAvailable: true,
      price: rate > 0 ? rate : null,
      priceUnit: rate > 0 ? 'hour' : null,
    );
  }

  /// Posts a quick job to workers nearby (POST /instant-work/dispatch). It
  /// stays open for 3 minutes; the first worker to accept gets it.
  Future<SpotGig> postRequest(HireRequestDraft draft) async {
    final response = await _client.post(
      ApiConstants.instantDispatch,
      data: draft.toJson(),
    );
    return _gig(response.data);
  }

  /// My latest quick job that is not closed yet, or null
  /// (GET /instant-work/recruiter/active-job; `null` = none).
  Future<SpotGig?> getActiveRequest() async {
    final response = await _client.get(ApiConstants.instantHirerActiveJob);
    final data = response.data;
    if (data == null || (data is String && data.trim().isEmpty)) return null;
    return _gig(data);
  }

  static SpotGig _gig(dynamic data) {
    if (data is Map<String, dynamic>) {
      final gig = SpotGig.fromJson(data);
      if (gig.id.isNotEmpty) return gig;
    }
    throw const AppServerException('Unexpected response from server.');
  }
}

final instantHireRepositoryProvider = Provider<InstantHireRepository>(
  (ref) => InstantHireRepository(ref.watch(apiClientProvider)),
);

/// Nearby workers come from the hiring radar, which needs a login. Guests
/// get [NearbyProfessionalsSignInRequired] and no request is made.
class RadarNearbyProfessionalsRepository
    implements NearbyProfessionalsRepository {
  RadarNearbyProfessionalsRepository(this._ref);

  final Ref _ref;

  @override
  Future<List<NearbyProfessional>> findNearby(NearbyProfessionalsQuery query) {
    if (_ref.read(sessionUserIdProvider) == null) {
      throw const NearbyProfessionalsSignInRequired();
    }
    final category = query.categoryId;
    var skill = '';
    if (category != null) {
      for (final c in InstantServiceCategory.values) {
        if (c.id == category) skill = c.label;
      }
    }
    return _ref
        .read(instantHireRepositoryProvider)
        .findWorkers(
          lat: query.location.latitude,
          lng: query.location.longitude,
          skill: skill,
          radiusKm: query.radiusKm,
        );
  }
}
