import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/user_profile.dart';

/// Looks up another user's public profile (GET /user/:id).
///
/// Chat conversations from the backend only contain participant IDs, so this
/// is used to show real names and photos. Results are cached per user ID by
/// Riverpod, so each person is fetched only once while the app is open.
/// Returns null when the profile is private (403), missing, or offline.
final userLookupProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  if (userId.isEmpty) return null;
  try {
    final response = await ref
        .read(apiClientProvider)
        .get('${ApiConstants.userById}$userId');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return UserProfile.fromJson(data);
    }
  } catch (_) {
    // Private, not found, or offline: caller shows a fallback label
  }
  return null;
});

/// Display name for a user, with a friendly fallback when unknown
String displayNameFor(UserProfile? user) {
  final name = user?.name.trim() ?? '';
  return name.isNotEmpty ? name : 'KaamMilega User';
}
