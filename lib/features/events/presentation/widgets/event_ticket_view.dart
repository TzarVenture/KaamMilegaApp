import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/event_ticket.dart';

/// Opens a ticket issued by the server in a bottom sheet.
Future<void> showEventTicketSheet(BuildContext context, EventTicket ticket) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              const SheetDragHandle(),
              EventTicketCard(ticket: ticket),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Event ticket with its entry QR code and the details saved by the server.
class EventTicketCard extends StatelessWidget {
  const EventTicketCard({super.key, required this.ticket});

  final EventTicket ticket;

  @override
  Widget build(BuildContext context) {
    final title = ticket.eventTitle.isNotEmpty ? ticket.eventTitle : 'Event';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (ticket.whenLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          _IconLine(icon: Icons.calendar_today_rounded, text: ticket.whenLabel),
        ],
        if (ticket.eventLocation.isNotEmpty) ...[
          const SizedBox(height: 4),
          _IconLine(
            icon: Icons.location_on_outlined,
            text: ticket.eventLocation,
          ),
        ],
        const SizedBox(height: 16),
        if (ticket.qrCodeData.isNotEmpty && ticket.isConfirmed)
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Semantics(
                    label: 'Entry QR code for ticket ${ticket.ticketNumber}',
                    image: true,
                    child: QrImageView(
                      data: ticket.qrCodeData,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Show this QR code at the entry',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ticket.isConfirmed
                  ? 'Entry code not available for this ticket.'
                  : 'This ticket is ${ticket.statusLabel.toLowerCase()} '
                        'and cannot be used for entry.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: AppFonts.secondary),
          child: Column(
            children: [
              _DetailRow(label: 'Ticket no.', value: ticket.ticketNumber),
              if (ticket.attendeeName.isNotEmpty)
                _DetailRow(label: 'Attendee', value: ticket.attendeeName),
              if (ticket.attendeeEmail.isNotEmpty)
                _DetailRow(label: 'Email', value: ticket.attendeeEmail),
              if (ticket.attendeePhone.isNotEmpty)
                _DetailRow(label: 'Phone', value: ticket.attendeePhone),
              _DetailRow(label: 'Payment', value: ticket.paymentLabel),
              if (ticket.razorpayPaymentId.isNotEmpty)
                _DetailRow(
                  label: 'Payment ID',
                  value: ticket.razorpayPaymentId,
                ),
              _DetailRow(label: 'Status', value: ticket.statusLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.moduleEventsText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
