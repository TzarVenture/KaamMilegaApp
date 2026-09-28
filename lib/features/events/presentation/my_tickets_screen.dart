import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/event_ticket.dart';
import '../providers/event_ticket_provider.dart';
import 'widgets/event_ticket_view.dart';

/// Confirmed event tickets of the signed-in user (GET /events/my/tickets).
class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myEventTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Tickets',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myEventTicketsProvider.future),
        child: ticketsAsync.when(
          data: (tickets) {
            if (tickets.isEmpty) {
              return NetworkStateView(
                isEmpty: true,
                emptyTitle: 'No tickets yet',
                emptyMessage:
                    'Register for an event or buy a ticket and it will '
                    'appear here.',
                emptyAction: ElevatedButton(
                  onPressed: () => context.push('/events'),
                  child: const Text('Browse Events'),
                ),
                child: const SizedBox.shrink(),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => FadeSlideIn(
                index: index,
                child: _TicketTile(
                  ticket: tickets[index],
                  onTap: () => showEventTicketSheet(context, tickets[index]),
                ),
              ),
            );
          },
          loading: () => const ShimmerLoadingList(count: 4, itemHeight: 96),
          error: (err, _) => NetworkStateView.fromError(
            err,
            onRetry: () => ref.invalidate(myEventTicketsProvider),
          ),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});

  final EventTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = ticket.eventTitle.isNotEmpty ? ticket.eventTitle : 'Event';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.moduleEventsLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.moduleEvents,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ticket.whenLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ticket.whenLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${ticket.ticketNumber} · ${ticket.paymentLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
