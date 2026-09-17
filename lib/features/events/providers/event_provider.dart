import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';

class EventsNotifier extends AsyncNotifier<List<EventItem>> {
  @override
  Future<List<EventItem>> build() async {
    final repo = ref.watch(eventRepositoryProvider);
    final user = ref.watch(authProvider).user;
    return repo.getEvents(currentUserId: user?.id);
  }

  /// Reload events from backend API
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(eventRepositoryProvider);
      final user = ref.read(authProvider).user;
      return repo.getEvents(currentUserId: user?.id);
    });
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
}

final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<EventItem>>(EventsNotifier.new);
