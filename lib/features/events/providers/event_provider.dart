import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/event.dart';
import '../models/event_participant.dart';
import '../repositories/event_repository.dart';

/// What the Events tab asks the server for (same filters as the website).
class EventsQuery {
  const EventsQuery({
    this.search = '',
    this.isPaid,
    this.upcomingFirst = false,
  });

  /// Matches title, organizer or category on the server.
  final String search;

  /// true: paid only, false: free only, null: all.
  final bool? isPaid;

  /// Soonest date first instead of newest added first.
  final bool upcomingFirst;

  EventsQuery copyWith({String? search, bool? upcomingFirst}) => EventsQuery(
    search: search ?? this.search,
    isPaid: isPaid,
    upcomingFirst: upcomingFirst ?? this.upcomingFirst,
  );

  EventsQuery withPricing(bool? paid) =>
      EventsQuery(search: search, isPaid: paid, upcomingFirst: upcomingFirst);

  @override
  bool operator ==(Object other) =>
      other is EventsQuery &&
      other.search == search &&
      other.isPaid == isPaid &&
      other.upcomingFirst == upcomingFirst;

  @override
  int get hashCode => Object.hash(search, isPaid, upcomingFirst);
}

class EventsQueryNotifier extends Notifier<EventsQuery> {
  @override
  EventsQuery build() => const EventsQuery();

  void set(EventsQuery query) {
    if (query != state) state = query;
  }
}

/// The Events tab's current search, pricing and sort. Changing it reloads
/// the list from page 1.
final eventsQueryProvider = NotifierProvider<EventsQueryNotifier, EventsQuery>(
  EventsQueryNotifier.new,
);

class EventsNotifier extends AsyncNotifier<List<EventItem>> {
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;

  /// More events exist on the server than are loaded.
  bool get hasMore => (state.value?.length ?? 0) < _total;

  /// A next page is being loaded.
  bool get isLoadingMore => _loadingMore;

  /// How many events match on the server.
  int get total => _total;

  @override
  Future<List<EventItem>> build() async {
    final query = ref.watch(eventsQueryProvider);
    final user = ref.watch(authProvider).user;
    _page = 1;
    _loadingMore = false;
    final result = await _fetch(query, page: 1, userId: user?.id);
    _total = result.total;
    return result.items;
  }

  Future<({List<EventItem> items, int total})> _fetch(
    EventsQuery query, {
    required int page,
    String? userId,
  }) {
    return ref
        .read(eventRepositoryProvider)
        .getEventsPage(
          search: query.search,
          isPaid: query.isPaid,
          upcomingFirst: query.upcomingFirst,
          page: page,
          currentUserId: userId,
        );
  }

  /// Reload events from backend API (page 1, same filters)
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Loads the next page and adds it to the list. Returns false when it
  /// failed (the loaded events stay; the screen offers to try again).
  Future<bool> loadMore() async {
    final current = state.value;
    if (current == null || _loadingMore || !hasMore) return true;
    _loadingMore = true;
    state = AsyncValue.data(current); // repaint: show the loading row
    final query = ref.read(eventsQueryProvider);
    try {
      final result = await _fetch(
        query,
        page: _page + 1,
        userId: ref.read(authProvider).user?.id,
      );
      if (!ref.mounted) return false;
      // A filter changed meanwhile: this page belongs to the old list
      // (the list has been reloaded for the new filter).
      if (query != ref.read(eventsQueryProvider)) {
        _loadingMore = false;
        return true;
      }
      _page++;
      _total = result.total;
      final seen = current.map((e) => e.id).toSet();
      _loadingMore = false;
      state = AsyncValue.data([
        ...current,
        ...result.items.where((e) => seen.add(e.id)),
      ]);
      return true;
    } catch (_) {
      if (!ref.mounted) return false;
      _loadingMore = false;
      state = AsyncValue.data(current);
      return false;
    }
  }

  /// Register for an event with optimistic UI update and fallback rollback
  Future<bool> registerForEvent(String eventId) async {
    final previousState = state;
    final currentList = state.value ?? [];

    // Optimistically mark as registered in the UI
    state = AsyncValue.data(
      currentList.map((e) {
        if (e.id == eventId) {
          return e.copyWith(
            isRegistered: true,
            attendeesCount: e.attendeesCount + 1,
            availableSeats: e.capacity > 0 && e.availableSeats > 0
                ? e.availableSeats - 1
                : e.availableSeats,
          );
        }
        return e;
      }).toList(),
    );

    try {
      final repo = ref.read(eventRepositoryProvider);
      final success = await repo.registerForEvent(eventId);
      if (!success) {
        state = previousState;
        return false;
      }
      return true;
    } catch (err) {
      state = previousState;
      rethrow;
    }
  }

  /// Shows [eventId] as registered after the server issued a ticket (paid
  /// purchase), without reloading the whole list.
  void markRegistered(String eventId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.map((e) {
        if (e.id != eventId || e.isRegistered) return e;
        return e.copyWith(
          isRegistered: true,
          attendeesCount: e.attendeesCount + 1,
          availableSeats: e.capacity > 0 && e.availableSeats > 0
              ? e.availableSeats - 1
              : e.availableSeats,
        );
      }).toList(),
    );
  }
}

final eventsProvider = AsyncNotifierProvider<EventsNotifier, List<EventItem>>(
  EventsNotifier.new,
);

/// One event fresh from the server (GET /events/:id), loaded when its page
/// opens so seats and price are current.
final eventDetailProvider = FutureProvider.autoDispose
    .family<EventItem, String>((ref, eventId) {
      final userId = ref.watch(authProvider.select((s) => s.user?.id));
      return ref
          .watch(eventRepositoryProvider)
          .getEvent(eventId, currentUserId: userId);
    });

/// Who is attending an event (public list, loaded when the event opens).
final eventAttendeesProvider = FutureProvider.autoDispose
    .family<EventAttendees, String>(
      (ref, eventId) =>
          ref.watch(eventRepositoryProvider).getAttendees(eventId),
    );
