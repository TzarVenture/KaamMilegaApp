import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_gig.dart';
import '../repositories/instant_hire_repository.dart';

/// Instant Milega has two modes: finding a worker (Hire) and finding a gig
/// (Work). The same account can use both.
enum InstantMode { work, hire }

class InstantModeNotifier extends Notifier<InstantMode> {
  @override
  InstantMode build() => InstantMode.work;

  /// Only changes what is shown; never sends or pays anything.
  void select(InstantMode mode) => state = mode;
}

final instantModeProvider = NotifierProvider<InstantModeNotifier, InstantMode>(
  InstantModeNotifier.new,
);

/// My latest quick job (Hire) that is not closed yet; null = none or a
/// guest (no request without a session).
final activeHireRequestProvider = FutureProvider.autoDispose<SpotGig?>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return null;
  return ref.watch(instantHireRepositoryProvider).getActiveRequest();
});

enum HirePostOutcome { posted, failed, unknown }

class HirePostResult {
  const HirePostResult(this.outcome, this.message, {this.gig});

  final HirePostOutcome outcome;
  final String message;
  final SpotGig? gig;
}

/// Posts a quick job; the result comes only from the server.
class InstantHireActions {
  InstantHireActions(this._ref);

  final Ref _ref;

  static const String unknownOutcome =
      'We could not confirm that your request was sent. Check its status '
      'below before posting again.';

  Future<HirePostResult> post(HireRequestDraft draft) async {
    try {
      final gig = await _ref
          .read(instantHireRepositoryProvider)
          .postRequest(draft);
      _ref.invalidate(activeHireRequestProvider);
      return HirePostResult(
        HirePostOutcome.posted,
        'Request sent to workers near you.',
        gig: gig,
      );
    } on AppValidationException catch (e) {
      return HirePostResult(HirePostOutcome.failed, _sentence(e.message));
    } on AppAuthException catch (e) {
      return HirePostResult(HirePostOutcome.failed, e.message);
    } on AppNetworkException {
      return const HirePostResult(
        HirePostOutcome.failed,
        'No internet connection. Your request was not sent.',
      );
    } on AppException {
      // Timeout or server error: it may have been posted.
      _ref.invalidate(activeHireRequestProvider);
      return const HirePostResult(HirePostOutcome.unknown, unknownOutcome);
    }
  }

  static String _sentence(String m) {
    final t = m.trim();
    if (t.isEmpty) return 'Your request could not be sent.';
    return '${t[0].toUpperCase()}${t.substring(1)}';
  }
}

final instantHireActionsProvider = Provider<InstantHireActions>(
  InstantHireActions.new,
);
