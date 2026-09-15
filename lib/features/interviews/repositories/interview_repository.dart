import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../cities/repositories/city_repository.dart';
import '../models/interview.dart';

/// Repository for handling candidate interview schedules
class InterviewRepository {
  final ApiClient _client;

  InterviewRepository(this._client);

  /// Fetch candidate's scheduled interviews from km-backend
  Future<List<InterviewItem>> getMyInterviews() async {
    try {
      final response = await _client.get(ApiConstants.myInterviews);
      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['data'] is List) {
        list = body['data'];
      }

      return list
          .map((e) => InterviewItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final interviewRepositoryProvider = Provider<InterviewRepository>((ref) {
  return InterviewRepository(ref.watch(apiClientProvider));
});

final myInterviewsProvider = FutureProvider<List<InterviewItem>>((ref) {
  return ref.watch(interviewRepositoryProvider).getMyInterviews();
});
