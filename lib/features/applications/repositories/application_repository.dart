import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/application.dart';

/// Repository for handling candidate applications
class ApplicationRepository {
  final ApiClient _client;

  ApplicationRepository(this._client);

  /// Apply to a job by ID
  Future<void> applyToJob(String jobId, {String coverLetter = ''}) async {
    await _client.post(
      ApiConstants.applications,
      data: {'job_id': jobId, 'cover_letter': coverLetter},
    );
  }

  /// Get candidate's submitted applications
  Future<List<ApplicationItem>> getMyApplications() async {
    try {
      final response = await _client.get(ApiConstants.myApplications);
      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['data'] is List) {
        list = body['data'];
      }

      return list
          .map((e) => ApplicationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(ref.watch(apiClientProvider));
});

final myApplicationsProvider = FutureProvider<List<ApplicationItem>>((ref) {
  return ref.watch(applicationRepositoryProvider).getMyApplications();
});
