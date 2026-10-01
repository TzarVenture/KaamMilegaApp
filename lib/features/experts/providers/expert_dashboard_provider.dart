import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/booking.dart';
import '../models/expert_offering.dart';
import '../repositories/expert_repository.dart';

/// True when the signed-in user has the "expert" role (given by the server
/// after Expert approval or a Pro Expert plan). The Expert Dashboard is
/// shown only then, like the website's "Expert Portal" menu.
final isExpertProvider = Provider<bool>((ref) {
  return ref.watch(
    authProvider.select(
      (s) =>
          s.isAuthenticated &&
          (s.user?.roles.any((r) => r.trim().toLowerCase() == 'expert') ??
              false),
    ),
  );
});

/// Sessions booked with me. No request without a session.
final expertBookingsProvider = FutureProvider.autoDispose<List<BookingItem>>((
  ref,
) {
  if (ref.watch(sessionUserIdProvider) == null) return const <BookingItem>[];
  return ref.watch(expertRepositoryProvider).getExpertBookings();
});

/// My session offerings.
final myOfferingsProvider = FutureProvider.autoDispose<List<ExpertOffering>>((
  ref,
) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <ExpertOffering>[];
  }
  return ref.watch(expertRepositoryProvider).getMyOfferings();
});

/// My weekly hours.
final myAvailabilityProvider = FutureProvider.autoDispose<List<WeeklyHours>>((
  ref,
) {
  if (ref.watch(sessionUserIdProvider) == null) return const <WeeklyHours>[];
  return ref.watch(expertRepositoryProvider).getMyAvailability();
});

/// The Expert's actions. Each returns null on success or the message to
/// show; lists and balances are always reloaded from the server afterwards
/// (nothing is changed locally, so the screen shows what the server holds).
class ExpertDashboardActions {
  ExpertDashboardActions(this._ref);

  final Ref _ref;

  ExpertRepository get _repo => _ref.read(expertRepositoryProvider);

  static const String unknownOutcome =
      'We could not confirm this change. The list has been refreshed; '
      'please check it before trying again.';

  /// Confirm, cancel or complete a booking. Completing or cancelling a
  /// paid booking moves money, so the wallet is reloaded too.
  Future<String?> setBookingStatus(BookingItem booking, String status) => _run(
    () => _repo.updateBookingStatus(booking.id, status),
    refresh: () {
      _ref.invalidate(expertBookingsProvider);
      unawaited(_ref.read(walletProvider.notifier).loadWallet());
    },
  );

  Future<String?> setMeetingLink(BookingItem booking, String link) => _run(
    () => _repo.updateMeetingLink(booking.id, link),
    refresh: () => _ref.invalidate(expertBookingsProvider),
  );

  Future<String?> saveOffering(ExpertOfferingDraft draft, {String? id}) => _run(
    () => _repo.saveOffering(draft, id: id),
    refresh: () => _ref.invalidate(myOfferingsProvider),
  );

  Future<String?> deleteOffering(ExpertOffering offering) => _run(
    () => _repo.deleteOffering(offering.id),
    refresh: () => _ref.invalidate(myOfferingsProvider),
  );

  Future<String?> saveAvailability(List<WeeklyHours> hours) => _run(
    () => _repo.saveAvailability(hours),
    refresh: () => _ref.invalidate(myAvailabilityProvider),
  );

  Future<String?> _run(
    Future<void> Function() action, {
    required void Function() refresh,
  }) async {
    try {
      await action();
      refresh();
      return null;
    } on AppValidationException catch (e) {
      // Refused by the app's own check or by the server: nothing changed.
      return _sentence(e.message);
    } on AppAuthException catch (e) {
      return e.message;
    } on AppNotFoundException {
      refresh();
      return 'This item no longer exists. The list has been refreshed.';
    } on AppException {
      // Timeout, dropped connection or server error: it may have happened.
      refresh();
      return unknownOutcome;
    }
  }

  static String _sentence(String message) {
    final m = message.trim();
    if (m.isEmpty) return 'The change could not be saved.';
    return '${m[0].toUpperCase()}${m.substring(1)}';
  }
}

final expertDashboardActionsProvider = Provider<ExpertDashboardActions>(
  ExpertDashboardActions.new,
);
