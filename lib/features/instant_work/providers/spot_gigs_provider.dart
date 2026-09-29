import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/models/wallet_transaction.dart';
import '../../wallet/repositories/wallet_repository.dart';
import '../models/spot_gig.dart';
import '../repositories/instant_candidate_repository.dart';
import '../services/location_service.dart';
import 'instant_candidate_provider.dart';
import 'instant_milega_provider.dart';

/// Gig pay credited to the wallet (wallet ledger, category gig_payout).
@immutable
class GigEarnings {
  const GigEarnings({
    this.today = 0,
    this.todayGigs = 0,
    this.week = 0,
    this.weekGigs = 0,
  });

  final double today;
  final int todayGigs;

  /// Last 7 days, today included.
  final double week;
  final int weekGigs;

  static const String category = 'gig_payout';

  factory GigEarnings.from(List<WalletTransaction> list, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekStart = startOfToday.subtract(const Duration(days: 6));
    var today = 0.0, week = 0.0;
    var todayGigs = 0, weekGigs = 0;
    for (final t in list) {
      if (t.category != category ||
          t.type != TransactionType.credit ||
          t.status != TransactionStatus.completed) {
        continue;
      }
      final at = t.createdAt.toLocal();
      if (!at.isBefore(weekStart)) {
        week += t.amount;
        weekGigs++;
      }
      if (!at.isBefore(startOfToday)) {
        today += t.amount;
        todayGigs++;
      }
    }
    return GigEarnings(
      today: today,
      todayGigs: todayGigs,
      week: week,
      weekGigs: weekGigs,
    );
  }
}

@immutable
class SpotGigsState {
  const SpotGigsState({
    this.hasLocation = false,
    this.feedLoading = false,
    this.feedError,
    this.feed,
    this.activeLoading = false,
    this.activeError,
    this.activeGig,
    this.claimingId,
    this.completing = false,
    this.earningsLoading = false,
    this.earningsError,
    this.earnings,
  });

  /// The phone's location is known (the list needs it).
  final bool hasLocation;

  final bool feedLoading;
  final Object? feedError;

  /// Open gigs near the user; null until first loaded.
  final List<SpotGig>? feed;

  final bool activeLoading;
  final Object? activeError;

  /// The gig the user claimed and has not been closed yet.
  final SpotGig? activeGig;

  /// Gig being claimed right now.
  final String? claimingId;
  final bool completing;

  final bool earningsLoading;
  final Object? earningsError;
  final GigEarnings? earnings;

  SpotGigsState copyWith({
    bool? feedLoading,
    Object? feedError,
    bool clearFeedError = false,
    List<SpotGig>? feed,
    bool? activeLoading,
    Object? activeError,
    bool clearActiveError = false,
    SpotGig? activeGig,
    bool clearActiveGig = false,
    String? claimingId,
    bool clearClaiming = false,
    bool? completing,
    bool? earningsLoading,
    Object? earningsError,
    bool clearEarningsError = false,
    GigEarnings? earnings,
  }) => SpotGigsState(
    hasLocation: hasLocation,
    feedLoading: feedLoading ?? this.feedLoading,
    feedError: clearFeedError ? null : (feedError ?? this.feedError),
    feed: feed ?? this.feed,
    activeLoading: activeLoading ?? this.activeLoading,
    activeError: clearActiveError ? null : (activeError ?? this.activeError),
    activeGig: clearActiveGig ? null : (activeGig ?? this.activeGig),
    claimingId: clearClaiming ? null : (claimingId ?? this.claimingId),
    completing: completing ?? this.completing,
    earningsLoading: earningsLoading ?? this.earningsLoading,
    earningsError: clearEarningsError
        ? null
        : (earningsError ?? this.earningsError),
    earnings: earnings ?? this.earnings,
  );
}

/// Spot gigs for workers: the live list of open gigs near the user (for
/// their primary trade), claiming one, the claimed gig until the employer
/// closes it, and gig earnings from the wallet. The list and the claimed
/// gig refresh every 15 s while the InstantMilega screen is open (open
/// gigs close within minutes).
class SpotGigsNotifier extends Notifier<SpotGigsState> {
  static const refreshEvery = Duration(seconds: 15);

  Timer? _timer;
  int _feedRun = 0;
  DeviceLocation? _location;
  String _skill = 'All';

  InstantCandidateRepository get _repo =>
      ref.read(instantCandidateRepositoryProvider);

  @override
  SpotGigsState build() {
    ref.onDispose(() => _timer?.cancel());
    final signedIn = ref.watch(sessionUserIdProvider) != null;
    _location = ref.watch(
      instantMilegaProvider.select(
        (s) => s.locationStatus == LocationStatus.ready ? s.location : null,
      ),
    );
    _skill = ref.watch(instantCandidateProvider.select((s) => s.skill));
    _timer?.cancel();
    _timer = null;
    if (!signedIn) return const SpotGigsState();

    Future.microtask(() {
      if (!ref.mounted) return;
      refreshAll();
      _timer?.cancel();
      _timer = Timer.periodic(refreshEvery, (_) => _poll());
    });
    return SpotGigsState(
      hasLocation: _location != null,
      feedLoading: _location != null,
      activeLoading: true,
      earningsLoading: true,
    );
  }

  bool get _signedIn => ref.read(sessionUserIdProvider) != null;

  Future<void> refreshAll() =>
      Future.wait([loadFeed(), loadActive(), loadEarnings()]);

  Future<void> loadFeed({bool silent = false}) async {
    final location = _location;
    if (location == null || !_signedIn) return;
    final run = ++_feedRun;
    if (!silent) {
      state = state.copyWith(feedLoading: true, clearFeedError: true);
    }
    try {
      final gigs = await _repo.getNearbyGigs(
        lat: location.latitude,
        lng: location.longitude,
        skill: _skill,
      );
      // A newer request (other trade or place) answers instead.
      if (!ref.mounted || run != _feedRun) return;
      state = state.copyWith(
        feedLoading: false,
        clearFeedError: true,
        feed: gigs,
      );
    } catch (e) {
      if (!ref.mounted || run != _feedRun) return;
      // A failed background refresh keeps the list already shown.
      if (silent && state.feed != null) return;
      state = state.copyWith(feedLoading: false, feedError: e);
    }
  }

  Future<void> loadActive({bool silent = false}) async {
    if (!_signedIn) return;
    if (!silent) {
      state = state.copyWith(activeLoading: true, clearActiveError: true);
    }
    final hadGig = state.activeGig != null;
    try {
      final gig = await _repo.getActiveGig();
      if (!ref.mounted) return;
      state = gig == null
          ? state.copyWith(
              activeLoading: false,
              clearActiveError: true,
              clearActiveGig: true,
            )
          : state.copyWith(
              activeLoading: false,
              clearActiveError: true,
              activeGig: gig,
            );
      if (hadGig && gig == null) {
        // The employer closed the gig: the pay was credited.
        unawaited(loadEarnings());
      }
    } catch (e) {
      if (!ref.mounted) return;
      if (silent) return;
      state = state.copyWith(activeLoading: false, activeError: e);
    }
  }

  Future<void> loadEarnings() async {
    if (!_signedIn) return;
    state = state.copyWith(earningsLoading: true, clearEarningsError: true);
    try {
      final list = await ref
          .read(walletRepositoryProvider)
          .getTransactions(limit: 100, category: GigEarnings.category);
      if (!ref.mounted) return;
      state = state.copyWith(
        earningsLoading: false,
        earnings: GigEarnings.from(list, DateTime.now()),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(earningsLoading: false, earningsError: e);
    }
  }

  void _poll() {
    if (!ref.mounted || state.claimingId != null || state.completing) return;
    unawaited(loadFeed(silent: true));
    unawaited(loadActive(silent: true));
  }

  /// Claims [gig]; one pass gig is used when it works.
  Future<InstantActionResult> claim(SpotGig gig) async {
    if (state.claimingId != null) {
      return (outcome: InstantActionOutcome.failed, message: '');
    }
    if (state.activeGig != null) {
      return (
        outcome: InstantActionOutcome.failed,
        message: 'Finish your current gig before claiming another one.',
      );
    }
    state = state.copyWith(claimingId: gig.id);
    try {
      final claimed = await _repo.claimGig(gig.id);
      if (!ref.mounted) return _gone;
      state = state.copyWith(
        clearClaiming: true,
        activeGig: claimed,
        feed: [...?state.feed?.where((g) => g.id != gig.id)],
      );
      _refreshPass();
      return (
        outcome: InstantActionOutcome.success,
        message: 'Gig claimed. Contact the employer and head to the site.',
      );
    } on InstantPassRequired catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(clearClaiming: true);
      _refreshPass();
      return (outcome: InstantActionOutcome.passRequired, message: e.message);
    } on AppValidationException catch (e) {
      // Taken by someone else or closed: show the fresh list.
      if (!ref.mounted) return _gone;
      state = state.copyWith(clearClaiming: true);
      unawaited(loadFeed(silent: true));
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppAuthException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(clearClaiming: true);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppException {
      // No answer: the claim may have gone through. Ask the server.
      if (!ref.mounted) return _gone;
      state = state.copyWith(clearClaiming: true);
      unawaited(loadActive());
      unawaited(loadFeed(silent: true));
      _refreshPass();
      return (
        outcome: InstantActionOutcome.unknown,
        message: 'Could not confirm the claim. Checking your gigs...',
      );
    }
  }

  /// Marks the claimed gig as done; the employer then confirms it.
  Future<InstantActionResult> completeActive() async {
    final gig = state.activeGig;
    if (gig == null || state.completing || !gig.canComplete) {
      return (outcome: InstantActionOutcome.failed, message: '');
    }
    state = state.copyWith(completing: true);
    try {
      final updated = await _repo.completeGig(gig.id);
      if (!ref.mounted) return _gone;
      state = state.copyWith(completing: false, activeGig: updated);
      return (
        outcome: InstantActionOutcome.success,
        message: 'Marked as complete. Waiting for the employer to confirm.',
      );
    } on AppValidationException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(completing: false);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppAuthException catch (e) {
      if (!ref.mounted) return _gone;
      state = state.copyWith(completing: false);
      return (outcome: InstantActionOutcome.failed, message: e.message);
    } on AppException {
      if (!ref.mounted) return _gone;
      state = state.copyWith(completing: false);
      unawaited(loadActive());
      return (
        outcome: InstantActionOutcome.unknown,
        message: 'Could not confirm. Showing the latest from the server.',
      );
    }
  }

  void _refreshPass() {
    // Pass gigs left come from the server.
    unawaited(ref.read(instantCandidateProvider.notifier).load());
  }

  static const InstantActionResult _gone = (
    outcome: InstantActionOutcome.failed,
    message: '',
  );
}

final spotGigsProvider =
    NotifierProvider.autoDispose<SpotGigsNotifier, SpotGigsState>(
      SpotGigsNotifier.new,
    );
