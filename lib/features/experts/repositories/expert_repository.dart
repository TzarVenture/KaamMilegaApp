import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/expert_profile.dart';

final expertRepositoryProvider = Provider<ExpertRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ExpertRepository(apiClient);
});

class ExpertRepository {
  final ApiClient _apiClient;

  ExpertRepository(this._apiClient);

  /// Fetch list of mentors & experts from /api/mentorships
  Future<List<ExpertItem>> getExperts({String? category, String? query}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.mentorships,
        queryParameters: {
          if (category != null && category.isNotEmpty && category != 'All')
            'category': category,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List list = [];
        if (data is Map && data['data'] is List) {
          list = data['data'] as List;
        } else if (data is List) {
          list = data;
        }

        final items = list
            .whereType<Map>()
            .map((e) => ExpertItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          return items.where((item) {
            return item.title.toLowerCase().contains(q) ||
                item.expertName.toLowerCase().contains(q) ||
                item.description.toLowerCase().contains(q) ||
                item.category.toLowerCase().contains(q);
          }).toList();
        }

        return items;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch single expert details from /api/mentorships/:id
  Future<ExpertItem?> getExpertById(String id) async {
    try {
      final response = await _apiClient.get('${ApiConstants.mentorships}/$id');
      if (response.data is Map) {
        return ExpertItem.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Book session with expert
  Future<bool> bookSession({
    required String mentorshipId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConstants.mentorships}/book',
        data: {
          'mentorship_id': mentorshipId,
          'scheduled_at': scheduledAt.toIso8601String(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
