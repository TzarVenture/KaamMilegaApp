import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/interview.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/response_list.dart';

/// Repository for handling candidate interview schedules
class InterviewRepository {
  final ApiClient _client;

  InterviewRepository(this._client);

  /// Fetch candidate's scheduled interviews from km-backend
  /// Throws on failure (network, 401, 404, 5xx, bad data) so the screen can
  /// show an error instead of an empty list.
  Future<List<InterviewItem>> getMyInterviews() async {
    final response = await _client.get(ApiConstants.myInterviews);
    return readListResponse(response.data).map(InterviewItem.fromJson).toList();
  }
}

final interviewRepositoryProvider = Provider<InterviewRepository>((ref) {
  return InterviewRepository(ref.watch(apiClientProvider));
});

/// The signed-in user's interviews. Rebuilt on logout / account switch;
/// guests have none and no request is made for them.
final myInterviewsProvider = FutureProvider<List<InterviewItem>>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <InterviewItem>[];
  }
  return ref.watch(interviewRepositoryProvider).getMyInterviews();
});
