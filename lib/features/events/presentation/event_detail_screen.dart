import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/auth_guard.dart';

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

  /// The event as fresh from the server (GET /events/:id) once loaded,
  /// otherwise the copy from the list; seats and price may have changed.
  EventItem get _event =>
      ref.read(eventDetailProvider(widget.event.id)).asData?.value ??
      widget.event;

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
      ref.invalidate(eventDetailProvider(widget.event.id));
    }
    _showMessage(
      success
          ? 'Successfully registered for ${_event.title}!'
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
    final event = _event;
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
        ref.invalidate(eventDetailProvider(widget.event.id));
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
              .confirmOnlinePayment(_event, attendee, payment);
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
    if (_event.isSoldOut) return null;
    return _event.requiresPayment ? _handleBuyTicket : _handleRegister;
  }

  String get _primaryLabel {
    if (_isRegistered) return 'View ticket';
    if (_event.isSoldOut) return 'Sold out';
    if (_event.requiresPayment) {
      return 'Buy ticket · ${_event.priceLabel}';
    }
    return 'Register for Event';
  }

  String get _priceAndSeatsLine {
    final event = _event;
    final price = event.requiresPayment
        ? '${event.priceLabel} per ticket'
        : 'Free entry';
    final seats = event.seatsLeft;
    if (seats == null) return price;
    if (event.isSoldOut) return '$price · Sold out';
    return '$price · $seats ${seats == 1 ? 'seat' : 'seats'} left';
  }

  /// Online session: no venue, or the venue is a meeting link or says
  /// online / Zoom / Meet (same rule as the website).
  bool _isOnline(EventItem e) {
    final l = e.location.trim().toLowerCase();
    return l.isEmpty ||
        l.contains('online') ||
        l.contains('zoom') ||
        l.contains('meet') ||
        l.startsWith('http');
  }

  /// The real meeting link, when the organizer put one as the location.
  /// Never an invented link.
  String? _meetingUrl(EventItem e) {
    final l = e.location.trim();
    final uri = Uri.tryParse(l);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    return l;
  }

  Future<void> _openMeeting(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      _showMessage('Could not open the meeting link.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load the event fresh; the page repaints when it arrives. If that
    // fails the list copy stays on screen (it is real data, only older).
    ref.watch(eventDetailProvider(widget.event.id));
    ref.listen(eventDetailProvider(widget.event.id), (_, next) {
      final fresh = next.asData?.value;
      if (fresh != null && fresh.isRegistered && !_isRegistered) {
        setState(() => _isRegistered = true);
      }
    });
    final event = _event;
    final online = _isOnline(event);
    final meetingUrl = _meetingUrl(event);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _BookingBar(
        info: _priceAndSeatsLine,
        label: _primaryLabel,
        loading: _isRegistering,
        onPressed: _primaryAction,
        // Orange for buying a ticket, navy otherwise (mobile spec 7.4)
        accent: !_isRegistered && event.requiresPayment && !event.isSoldOut,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Navy header with the event picture; the main card overlaps it.
          Stack(
            children: [
              _EventHero(imageUrl: event.imageUrl),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 128, 16, 0),
                child: _MainCard(
                  event: event,
                  online: online,
                  registered: _isRegistered,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PassCard(event: event, online: online),
                const SizedBox(height: 16),
                if (online) ...[
                  _MeetingRoomCard(
                    registered: _isRegistered,
                    time: event.time,
                    meetingUrl: meetingUrl,
                    onJoin: meetingUrl == null
                        ? null
                        : () => _openMeeting(meetingUrl),
                    onViewTicket: _isRegistered ? _handleViewTicket : null,
                  ),
                  const SizedBox(height: 16),
                ],
                const _IncludesCard(),
                const SizedBox(height: 16),
                _ExpertCallout(
                  onApply: () => AuthGuard.openProtected(
                    context,
                    '/apply-expert',
                    message: 'Please log in to apply as an expert.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// PAGE PARTS
// ---------------------------------------------------------------------

const Color _amber = Color(0xFFB45309); // Events text-safe colour
const Color _amberBg = Color(0xFFFFFBEB);
const Color _amberBorder = Color(0xFFFDE68A);
const Color _green = Color(0xFF047857);
const Color _greenBg = Color(0xFFECFDF5);
const Color _greenBorder = Color(0xFFA7F3D0);

BoxDecoration _cardDecoration({Color? color, Color? border}) => BoxDecoration(
  color: color ?? Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: border ?? AppColors.border),
  boxShadow: [
    BoxShadow(
      color: AppColors.brandNavy.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ],
);

class _EventHero extends StatelessWidget {
  const _EventHero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    return Container(
      height: 180,
      width: double.infinity,
      color: AppColors.brandNavy,
      child: hasImage
          ? Opacity(
              opacity: 0.45,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          : Align(
              alignment: const Alignment(0, -0.5),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 32,
                  color: AppColors.moduleEvents,
                ),
              ),
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(
    this.label, {
    required this.color,
    required this.background,
    this.border,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final Color? border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tags, title, host and description.
class _MainCard extends StatefulWidget {
  const _MainCard({
    required this.event,
    required this.online,
    required this.registered,
  });

  final EventItem event;
  final bool online;
  final bool registered;

  @override
  State<_MainCard> createState() => _MainCardState();
}

class _MainCardState extends State<_MainCard> {
  static const int _foldLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final description = e.description.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (e.category.trim().isNotEmpty)
                _Tag(
                  e.category.trim(),
                  color: _amber,
                  background: _amberBg,
                  border: _amberBorder,
                ),
              e.requiresPayment
                  ? _Tag(
                      'Paid · ${e.priceLabel}',
                      color: AppColors.onAccent,
                      background: AppColors.accent,
                    )
                  : const _Tag(
                      'Free entry',
                      color: Colors.white,
                      background: AppColors.brandNavy,
                    ),
              if (widget.online)
                const _Tag(
                  'Live video session',
                  icon: Icons.videocam_outlined,
                  color: _green,
                  background: _greenBg,
                  border: _greenBorder,
                ),
              if (widget.registered)
                const _Tag(
                  'Registered',
                  icon: Icons.check_circle_rounded,
                  color: _green,
                  background: _greenBg,
                  border: _greenBorder,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            e.title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (e.organizer.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'Conducted by ',
                children: [
                  TextSpan(
                    text: e.organizer.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          // No description from the organizer: no section (no filler text)
          if (description.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            const Text(
              'About this event',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const style = TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                );
                final painter = TextPainter(
                  text: TextSpan(text: description, style: style),
                  maxLines: _foldLines,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final long = painter.didExceedMaxLines;
                painter.dispose();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      maxLines: long && !_expanded ? _foldLines : null,
                      overflow: long && !_expanded
                          ? TextOverflow.ellipsis
                          : TextOverflow.visible,
                      style: style,
                    ),
                    if (long)
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 40),
                        ),
                        child: Text(_expanded ? 'Show less' : 'Read more'),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Date, time, format, who registered and seats.
class _PassCard extends StatelessWidget {
  const _PassCard({required this.event, required this.online});

  final EventItem event;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final venue = e.location.trim();
    final seats = e.seatsLeft;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Event pass',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _Tag(
                  e.requiresPayment ? e.priceLabel : 'Free entry',
                  color: e.requiresPayment ? AppColors.onAccent : Colors.white,
                  background: e.requiresPayment
                      ? AppColors.accent
                      : AppColors.brandNavy,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _MetaRow(
            icon: Icons.calendar_today_rounded,
            iconColor: AppColors.moduleEvents,
            background: _amberBg,
            border: _amberBorder,
            label: 'DATE',
            value: e.date.trim().isNotEmpty ? e.date.trim() : 'To be announced',
          ),
          const SizedBox(height: 12),
          _MetaRow(
            icon: Icons.schedule_rounded,
            iconColor: AppColors.brandNavy,
            background: AppColors.background,
            border: AppColors.border,
            label: 'TIME',
            value: e.time.trim().isNotEmpty ? e.time.trim() : 'To be announced',
          ),
          const SizedBox(height: 12),
          _MetaRow(
            icon: online ? Icons.videocam_outlined : Icons.location_on_outlined,
            iconColor: AppColors.accent,
            background: AppColors.accentLight,
            border: AppColors.accentBorder,
            label: online ? 'FORMAT' : 'VENUE',
            value: online
                ? 'Online (video session)'
                : (venue.isNotEmpty ? venue : 'To be announced'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Faces, "N attending" and See all (public attendee list)
                EventAttendeesRow(eventId: e.id),
                if (seats != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    e.isSoldOut
                        ? 'All ${e.capacity} seats are taken'
                        : '$seats ${seats == 1 ? 'seat' : 'seats'} remaining '
                              'of ${e.capacity} total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: e.isSoldOut
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.border,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color border;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Meeting room: locked until the user has a pass; then the real link
/// (when the organizer gave one) or how it will be shared.
class _MeetingRoomCard extends StatelessWidget {
  const _MeetingRoomCard({
    required this.registered,
    required this.time,
    required this.meetingUrl,
    required this.onJoin,
    required this.onViewTicket,
  });

  final bool registered;
  final String time;
  final String? meetingUrl;
  final VoidCallback? onJoin;
  final VoidCallback? onViewTicket;

  @override
  Widget build(BuildContext context) {
    if (!registered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(color: _amberBg, border: _amberBorder),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: _amber),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live session meeting room',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'The meeting link and session details unlock for your '
                    'account once you reserve a pass.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 10),
                  _Tag(
                    'Locked for registered learners',
                    icon: Icons.lock_rounded,
                    color: _amber,
                    background: Colors.white,
                    border: _amberBorder,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final when = time.trim().isNotEmpty ? ' (${time.trim()})' : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(border: _greenBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _greenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.videocam_outlined, color: _green),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Live session room',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: _Tag(
                  'Pass active',
                  icon: Icons.check_circle_rounded,
                  color: _green,
                  background: _greenBg,
                  border: _greenBorder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meetingUrl != null
                ? 'Join a few minutes before the start$when. Keep your '
                      'ticket number ready; the host admits pass holders.'
                : 'The organizer has not added a meeting link yet. It will '
                      'be shared with pass holders before the session$when.',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (onJoin != null) ...[
            ElevatedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: const Text('Join live session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (onViewTicket != null)
            OutlinedButton.icon(
              onPressed: onViewTicket,
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Show my pass and QR code'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a pass gives, limited to what the app really provides.
class _IncludesCard extends StatelessWidget {
  const _IncludesCard();

  static const _items = [
    (
      Icons.videocam_outlined,
      'Live session access',
      'Join the session at its scheduled time.',
    ),
    (
      Icons.qr_code_2_rounded,
      'Digital pass with QR code',
      'Your pass is saved under My Tickets for entry.',
    ),
    (
      Icons.groups_outlined,
      'Meet other learners',
      'See who is attending and connect with them.',
    ),
    (
      Icons.support_agent_rounded,
      'Follow up with experts',
      'Book 1-on-1 sessions with experts on KaamMilega.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'What your pass includes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns on tablets, one on phones
              final twoCols = constraints.maxWidth >= 520;
              final width = twoCols
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (icon, title, text) in _items)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 20, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExpertCallout extends StatelessWidget {
  const _ExpertCallout({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you an experienced professional or expert?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Apply to become a KaamMilega expert. Host workshops, teach '
            'candidates and earn from your sessions.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onApply,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text('Apply as Expert')),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar that stays on screen (mobile spec 7.5): price and seats,
/// then the one main action.
class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.info,
    required this.label,
    required this.loading,
    required this.onPressed,
    required this.accent,
  });

  final String info;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bg = accent ? AppColors.accent : AppColors.primary;
    final fg = accent ? AppColors.onAccent : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                info,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: fg,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textSecondary,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    : Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
