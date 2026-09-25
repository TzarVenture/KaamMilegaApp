import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/local_storage.dart';
import '../models/application.dart';
import '../../auth/providers/auth_provider.dart';

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
  /// The signed-in user's applications (GET /applications/my).
  ///
  /// Errors are thrown (401, 404, 5xx, bad data), never turned into an empty
  /// list. Only when the device is offline / the request timed out is the
  /// last successful list shown (read-only cache).
  Future<List<ApplicationItem>> getMyApplications() async {
    try {
      final response = await _client.get(ApiConstants.myApplications);
      final dynamic body = response.data;
      List<dynamic> list;

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic> && body['data'] is List) {
        list = body['data'] as List;
      } else {
        throw const AppValidationException(
          'Unexpected response from server. Please try again.',
        );
      }

      final items = list.whereType<Map<String, dynamic>>().toList();
      final apps = items.map(ApplicationItem.fromJson).toList();

      // Cache the server items as received, so the offline copy keeps the
      // job title / company (nested `job`) exactly like the live list.
      try {
        LocalStorage.saveCachedApplications(items);
      } catch (_) {}

      return apps;
    } on AppException catch (e) {
      final offline = e is AppNetworkException || e is AppTimeoutException;
      if (offline) {
        final cached = LocalStorage.getCachedApplications();
        if (cached.apps.isNotEmpty) {
          try {
            return cached.apps.map(ApplicationItem.fromJson).toList();
          } catch (_) {
            // Unreadable cache: report the real (offline) error below.
          }
        }
      }
      rethrow;
    }
  }
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(ref.watch(apiClientProvider));
});

/// The signed-in user's applications. Rebuilt on logout / account switch;
/// guests have no applications and no request is made for them.
final myApplicationsProvider = FutureProvider<List<ApplicationItem>>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <ApplicationItem>[];
  }
  return ref.watch(applicationRepositoryProvider).getMyApplications();
});
