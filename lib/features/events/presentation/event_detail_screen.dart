import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/event.dart';
import '../models/event_ticket.dart';
import '../providers/event_provider.dart';
import '../providers/event_ticket_provider.dart';
import '../repositories/event_repository.dart';
import 'widgets/event_attendees.dart';
import 'widgets/event_ticket_view.dart';
import 'widgets/ticket_checkout_sheets.dart';
import '../../../app/theme/app_colors.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final EventItem event;

  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isRegistering = false;
  late bool _isRegistered;

  @override
  void initState() {
    super.initState();
    _isRegistered = widget.event.isRegistered;
  }

  bool _requireLogin(String message) {
    if (ref.read(authProvider).isAuthenticated) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () => context.push('/login'),
        ),
      ),
    );
    return true;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Free events: POST /events/:id/register.
  Future<void> _handleRegister() async {
    if (_requireLogin('Please log in to register for this event.')) return;

    setState(() => _isRegistering = true);
    var success = false;
    String? error;
    try {
      success = await ref
          .read(eventsProvider.notifier)
          .registerForEvent(widget.event.id);
    } on AppException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    setState(() {
      _isRegistering = false;
      if (success) _isRegistered = true;
    });
    if (success) {
      ref.invalidate(myEventTicketsProvider);
      ref.invalidate(eventAttendeesProvider(widget.event.id));
    }
    _showMessage(
      success
          ? 'Successfully registered for ${widget.event.title}!'
          : error ?? 'Could not complete registration. Please try again.',
      isError: !success,
    );
  }

  /// Paid events: attendee details, then wallet or Razorpay. The ticket is
  /// shown only after the server has issued it.
  Future<void> _handleBuyTicket() async {
    if (_requireLogin('Please log in to buy a ticket for this event.')) {
      return;
    }
    final event = widget.event;
    final user = ref.read(authProvider).user;
    final attendee = await showModalBottomSheet<EventAttendee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendeeDetailsSheet(
        event: event,
        initialName: user?.name ?? '',
        initialEmail: user?.email ?? '',
        initialPhone: user?.mobile ?? '',
      ),
    );
    if (attendee == null || !mounted) return;

    setState(() => _isRegistering = true);
    // Fresh balances from the server before offering the wallet
    await ref.read(walletProvider.notifier).loadWallet();
    if (!mounted) return;
    setState(() => _isRegistering = false);
    final walletState = ref.read(walletProvider);
    final method = await showModalBottomSheet<TicketPaymentMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TicketPaymentMethodSheet(
        event: event,
        walletAvailable:
            walletState.summary != null && !walletState.isComingSoon,
        mainBalance: walletState.summary?.mainBalance ?? 0,
      ),
    );
    if (method == null || !mounted) return;

    setState(() => _isRegistering = true);
    try {
      final checkout = ref.read(eventTicketCheckoutProvider);
      final result = method == TicketPaymentMethod.wallet
          ? await checkout.payWithWallet(event, attendee)
          : await checkout.payOnline(event, attendee);
      if (!mounted) return;
      await _handlePurchaseResult(result, attendee);
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _handlePurchaseResult(
    TicketPurchaseResult result,
    EventAttendee attendee,
  ) async {
    switch (result.outcome) {
      case TicketPurchaseOutcome.success:
        setState(() => _isRegistered = true);
        ref.invalidate(eventAttendeesProvider(widget.event.id));
        _showMessage(result.message);
        final ticket = result.ticket;
        if (ticket != null) await showEventTicketSheet(context, ticket);
        break;
      case TicketPurchaseOutcome.cancelled:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
        break;
      case TicketPurchaseOutcome.failed:
        _showMessage(result.message, isError: true);
        break;
      case TicketPurchaseOutcome.outcomeUnknown:
        await _showNotice('Could not confirm purchase', result.message);
        break;
      case TicketPurchaseOutcome.paidButUnconfirmed:
        final retry = await _showNotice(
          'Payment received, confirming',
          result.message,
          retryLabel: 'Try again',
        );
        final payment = result.payment;
        if (retry == true && payment != null && mounted) {
          final next = await ref
              .read(eventTicketCheckoutProvider)
              .confirmOnlinePayment(widget.event, attendee, payment);
          if (mounted) await _handlePurchaseResult(next, attendee);
        }
        break;
    }
  }

  /// Returns true when the retry action was chosen.
  Future<bool?> _showNotice(
    String title,
    String message, {
    String? retryLabel,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(retryLabel == null ? 'OK' : 'Close'),
          ),
          if (retryLabel != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(retryLabel),
            ),
        ],
      ),
    );
  }

  /// Shows the ticket the server issued for this event.
  Future<void> _handleViewTicket() async {
    setState(() => _isRegistering = true);
    try {
      final tickets = await ref.read(eventRepositoryProvider).getMyTickets();
      if (!mounted) return;
      EventTicket? ticket;
      for (final t in tickets) {
        if (t.eventId == widget.event.id) {
          ticket = t;
          break;
        }
      }
      if (ticket == null) {
        _showMessage(
          'You are registered for this event. No ticket was issued for '
          'this registration.',
        );
        return;
      }
      await showEventTicketSheet(context, ticket);
    } on AppException catch (e) {
      _showMessage(NetworkStateView.errorMessageFor(e), isError: true);
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  VoidCallback? get _primaryAction {
    if (_isRegistering) return null;
    if (_isRegistered) return _handleViewTicket;
    if (widget.event.isSoldOut) return null;
    return widget.event.requiresPayment ? _handleBuyTicket : _handleRegister;
  }

  String get _primaryLabel {
    if (_isRegistered) return 'View ticket';
    if (widget.event.isSoldOut) return 'Sold out';
    if (widget.event.requiresPayment) {
      return 'Buy ticket · ${widget.event.priceLabel}';
    }
    return 'Register for Event';
  }

  String get _priceAndSeatsLine {
    final event = widget.event;
    final price = event.requiresPayment
        ? '${event.priceLabel} per ticket'
        : 'Free entry';
    final seats = event.seatsLeft;
    if (seats == null) return price;
    if (event.isSoldOut) return '$price · Sold out';
    return '$price · $seats ${seats == 1 ? 'seat' : 'seats'} left';
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Event Banner Image or Placeholder
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB45309),
                  Color(0xFFD97706),
                  Color(0xFFF59E0B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: event.imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(event.imageUrl),
                      fit: BoxFit.cover,
                      // Missing picture: the gradient stays visible.
                      onError: (_, _) {},
                    )
                  : null,
            ),
            child: event.imageUrl.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 16),

          // Title & Category
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.organizer.isNotEmpty
                            ? event.organizer
                            : 'Community Event',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    if (_isRegistered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: Color(0xFF059669),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Registered',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (event.organizer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Organized by ${event.organizer}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${event.date} • ${event.time}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location.isNotEmpty
                            ? event.location
                            : 'Online via KaamMilega Live',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _priceAndSeatsLine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                EventAttendeesRow(eventId: event.id),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About Event
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About this Event',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description.isNotEmpty ? event.description : 'Join fellow job seekers, expert speakers, and recruiting partners in this interactive session.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Register Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _primaryAction,
              style: ElevatedButton.styleFrom(
                // Same colour as the Events + button
                backgroundColor: AppColors.moduleEvents,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isRegistering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _primaryLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
