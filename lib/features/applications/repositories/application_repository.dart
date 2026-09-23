import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/local_storage.dart';
import '../models/application.dart';

/// Repository for handling candidate applications with offline caching and write safety
class ApplicationRepository {
  final ApiClient _client;

  ApplicationRepository(this._client);

  /// Apply to a job by ID (strictly requires active network)
  Future<void> applyToJob(
    String jobId, {
    String coverLetter = '',
    String resumeUrl = '',
  }) async {
    if (!ConnectivityService().isOnline) {
      throw const AppNetworkException(
        'Internet connection required to apply for jobs.',
      );
    }

    await _client.post(
      ApiConstants.applications,
      data: {
        'job_id': jobId,
        'cover_letter': coverLetter,
        if (resumeUrl.isNotEmpty) 'resume_url': resumeUrl,
      },
    );
  }

  /// Ask the server whether the signed-in user already applied to [jobId]
  /// (GET /applications/check/:jobId -> {"applied": bool}).
  Future<bool> hasApplied(String jobId) async {
    final token = LocalStorage.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      final response = await _client.get(
        '${ApiConstants.applicationCheck}$jobId',
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['applied'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get candidate's submitted applications (with offline cache fallback)
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

      final apps = list
          .map((e) => ApplicationItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache successful response
      try {
        final cacheList = apps
            .map(
              (a) => {
                'id': a.id,
                'job_id': a.jobId,
                'candidate_id': a.candidateId,
                'job_title': a.jobTitle,
                'company_name': a.companyName,
                'status': a.status,
                'cover_letter': a.coverLetter,
                'created_at': a.createdAt?.toIso8601String(),
              },
            )
            .toList();
        LocalStorage.saveCachedApplications(cacheList);
      } catch (_) {}

      return apps;
    } catch (_) {
      // Fallback to offline cache
      final cached = LocalStorage.getCachedApplications();
      if (cached.apps.isNotEmpty) {
        try {
          return cached.apps.map((m) => ApplicationItem.fromJson(m)).toList();
        } catch (_) {}
      }
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
