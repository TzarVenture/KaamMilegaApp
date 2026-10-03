import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/event.dart';
import '../../models/event_ticket.dart';

/// How the user pays for a ticket.
enum TicketPaymentMethod { wallet, online }

/// Attendee details for a paid ticket; the backend requires name and email.
/// Returns null when the user closes the sheet.
class AttendeeDetailsSheet extends StatefulWidget {
  const AttendeeDetailsSheet({
    super.key,
    required this.event,
    this.initialName = '',
    this.initialEmail = '',
    this.initialPhone = '',
  });

  final EventItem event;
  final String initialName;
  final String initialEmail;
  final String initialPhone;

  @override
  State<AttendeeDetailsSheet> createState() => _AttendeeDetailsSheetState();
}

class _AttendeeDetailsSheetState extends State<AttendeeDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _email = TextEditingController(text: widget.initialEmail);
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      EventAttendee(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetDragHandle(),
                const Text(
                  'Attendee details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The ticket for ${widget.event.title} will be issued in '
                  'this name.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _name,
                  labelText: 'Full name',
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Please enter the attendee name'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _email,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Please enter an email';
                    if (!_emailPattern.hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _phone,
                  labelText: 'Phone (optional)',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: Text('Continue to pay ${widget.event.priceLabel}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Choose wallet or online payment for a ticket. The wallet option is
/// enabled only when the server-reported main balance covers the price.
class TicketPaymentMethodSheet extends StatelessWidget {
  const TicketPaymentMethodSheet({
    super.key,
    required this.event,
    required this.walletAvailable,
    required this.mainBalance,
  });

  final EventItem event;
  final bool walletAvailable;
  final double mainBalance;

  @override
  Widget build(BuildContext context) {
    final canUseWallet = walletAvailable && mainBalance >= event.price;
    final balance = '₹${mainBalance.toStringAsFixed(0)}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetDragHandle(),
            Text(
              'Pay ${event.priceLabel} for this ticket',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: canUseWallet,
              leading: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Pay from KaamMilega Wallet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                !walletAvailable
                    ? 'Wallet is not available right now'
                    : canUseWallet
                    ? 'Balance: $balance'
                    : 'Balance $balance is not enough. Add money in Wallet.',
              ),
              onTap: canUseWallet
                  ? () => Navigator.pop(context, TicketPaymentMethod.wallet)
                  : null,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.payments_rounded,
                color: AppColors.moduleEventsText,
              ),
              title: const Text(
                'Pay online',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('UPI, card or net banking via Razorpay'),
              onTap: () => Navigator.pop(context, TicketPaymentMethod.online),
            ),
          ],
        ),
      ),
    );
  }
}
