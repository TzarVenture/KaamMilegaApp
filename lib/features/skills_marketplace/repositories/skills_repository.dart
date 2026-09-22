import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/skill_item.dart';

final skillsRepositoryProvider = Provider<SkillsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SkillsRepository(apiClient);
});

class SkillsRepository {
  final ApiClient _apiClient;

  SkillsRepository(this._apiClient);

  /// Fetch list of skills with optional query & category filter from /skills
  Future<List<SkillItem>> getSkills({String? query, String? category}) async {
    final response = await _apiClient.get(
      ApiConstants.skills,
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (category != null && category.isNotEmpty && category != 'All')
          'category': category,
      },
    );

    if (response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(SkillItem.fromJson)
          .toList();
    } else if (response.data is Map<String, dynamic> &&
        response.data['data'] is List) {
      return (response.data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(SkillItem.fromJson)
          .toList();
    }
    return [];
  }

  /// Fetch distinct categories from /skills/categories
  Future<List<String>> getCategories() async {
    final response = await _apiClient.get('${ApiConstants.skills}/categories');
    if (response.data is List) {
      return (response.data as List).map((e) => e.toString()).toList();
    } else if (response.data is Map<String, dynamic> &&
        response.data['categories'] is List) {
      return (response.data['categories'] as List)
          .map((e) => e.toString())
          .toList();
    }
    return [];
  }
}
