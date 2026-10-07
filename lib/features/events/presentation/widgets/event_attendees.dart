import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../../auth/models/user_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/presentation/widgets/connect_like_you_section.dart'
    show PersonAvatar;
import '../../models/event_participant.dart';
import '../../providers/event_provider.dart';

UserProfile _asProfile(EventParticipant p) => UserProfile(
  id: p.id,
  mobile: '',
  name: p.displayName,
  profileImage: p.profileImage,
);

/// "Who is attending" on the event page: a few photos, the count and
/// "See all" (opens the full list).
class EventAttendeesRow extends ConsumerWidget {
  const EventAttendeesRow({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventId.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(eventAttendeesProvider(eventId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load who is attending.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(eventAttendeesProvider(eventId)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (list) {
        if (list.total <= 0) {
          return const Text(
            'No one has joined yet. Be the first.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          );
        }
        final faces = list.people.take(4).toList();
        return InkWell(
          onTap: list.people.isEmpty
              ? null
              : () => showEventAttendeesSheet(
                  context,
                  list,
                  // The page's context: the sheet is closed by then.
                  onOpenMember: (id) =>
                      AuthGuard.openProtected(context, '/members/$id'),
                ),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: faces.isEmpty ? 0 : 22.0 * faces.length + 10,
                  height: 32,
                  child: Stack(
                    children: [
                      for (var i = 0; i < faces.length; i++)
                        Positioned(
                          left: 22.0 * i,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ExcludeSemantics(
                              child: PersonAvatar(
                                user: _asProfile(faces[i]),
                                size: 29,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${list.total} attending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (list.people.isNotEmpty)
                  const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Opens the attendee list of [eventId] from anywhere, for example an
/// event card. The sheet loads the list (GET /events/:id/attendees) and
/// shows loading, an error with Retry, or the people.
Future<void> showEventAttendeesFor(BuildContext context, String eventId) {
  final page = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Consumer(
      builder: (_, ref, _) {
        final async = ref.watch(eventAttendeesProvider(eventId));
        Widget box(Widget child) => SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                const SheetDragHandle(),
                Expanded(child: Center(child: child)),
              ],
            ),
          ),
        );
        return async.when(
          loading: () => box(const LinearProgressIndicator(minHeight: 2)),
          error: (_, _) => box(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load who is attending.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(eventAttendeesProvider(eventId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (list) => list.people.isEmpty
              ? box(
                  const Text(
                    'No one has joined yet. Be the first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : EventAttendeesSheet(
                  attendees: list,
                  // The page's context: the sheet is closed by then.
                  onOpenMember: (id) =>
                      AuthGuard.openProtected(page, '/members/$id'),
                ),
        );
      },
    ),
  );
}

Future<void> showEventAttendeesSheet(
  BuildContext context,
  EventAttendees attendees, {
  required ValueChanged<String> onOpenMember,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        EventAttendeesSheet(attendees: attendees, onOpenMember: onOpenMember),
  );
}

/// The full list, with a search box for longer lists. Tapping a person
/// opens their profile (sign-in needed, like every member profile).
class EventAttendeesSheet extends ConsumerStatefulWidget {
  const EventAttendeesSheet({
    super.key,
    required this.attendees,
    required this.onOpenMember,
  });

  final EventAttendees attendees;

  /// Opens a member's profile (called after the sheet closes).
  final ValueChanged<String> onOpenMember;

  @override
  ConsumerState<EventAttendeesSheet> createState() =>
      _EventAttendeesSheetState();
}

class _EventAttendeesSheetState extends ConsumerState<EventAttendeesSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionUserIdProvider);
    final q = _query.trim().toLowerCase();
    final people = q.isEmpty
        ? widget.attendees.people
        : widget.attendees.people
              .where(
                (p) =>
                    p.displayName.toLowerCase().contains(q) ||
                    p.subtitle.toLowerCase().contains(q),
              )
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Center(child: SheetDragHandle(bottomSpacing: 8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '${widget.attendees.total} attending',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (widget.attendees.people.length > 10)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: people.isEmpty
                ? const Center(
                    child: Text(
                      'No one matches your search.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final p = people[i];
                      final isMe = p.id == me;
                      return ListTile(
                        leading: PersonAvatar(user: _asProfile(p), size: 40),
                        title: Text(
                          isMe ? '${p.displayName} (you)' : p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: p.subtitle.isEmpty
                            ? null
                            : Text(
                                p.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: isMe
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                widget.onOpenMember(p.id);
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
