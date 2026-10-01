import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/booking.dart';
import '../models/expert_offering.dart';
import '../providers/expert_dashboard_provider.dart';
import '../repositories/expert_repository.dart';
import 'widgets/expert_offering_sheet.dart';
import 'widgets/weekly_hours_editor.dart';

/// Expert Dashboard (website: "Mentor Dashboard" in the Expert Portal):
/// sessions booked with me, my session offers and my weekly hours.
/// Only for users with the "expert" role.
class ExpertDashboardScreen extends ConsumerStatefulWidget {
  const ExpertDashboardScreen({super.key});

  @override
  ConsumerState<ExpertDashboardScreen> createState() =>
      _ExpertDashboardScreenState();
}

class _ExpertDashboardScreenState extends ConsumerState<ExpertDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh balances for the earnings card
    Future.microtask(() {
      if (mounted) ref.read(walletProvider.notifier).loadWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpert = ref.watch(isExpertProvider);
    if (!isExpert) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expert Dashboard')),
        body: const _NotExpertYet(),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Expert Dashboard'),
          bottom: const TabBar(
            labelColor: AppColors.brandNavy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.brandNavy,
            labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: 'Bookings'),
              Tab(text: 'My Sessions'),
              Tab(text: 'Hours'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_BookingsTab(), _OfferingsTab(), WeeklyHoursEditor()],
        ),
      ),
    );
  }
}

class _NotExpertYet extends StatelessWidget {
  const _NotExpertYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 44,
              color: AppColors.moduleExperts,
            ),
            const SizedBox(height: 12),
            const Text(
              'Only KaamMilega Experts can use this dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/apply-expert'),
              child: const Text('Become an Expert'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Bookings ---------------------------------------------------------------

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expertBookingsProvider);
    Future<void> refresh() async {
      ref.invalidate(expertBookingsProvider);
      await ref.read(walletProvider.notifier).loadWallet();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: async.when(
        loading: () => const ShimmerLoadingList(count: 3, itemHeight: 150),
        error: (e, _) => ListView(
          children: [
            const _EarningsCard(),
            SizedBox(
              height: 360,
              child: NetworkStateView.fromError(
                e,
                onRetry: () => ref.invalidate(expertBookingsProvider),
              ),
            ),
          ],
        ),
        data: (bookings) {
          final waiting = bookings.where((b) => b.status == 'pending');
          final confirmed = bookings.where((b) => b.status == 'confirmed');
          // Past sessions newest first
          final past = bookings
              .where((b) => b.status == 'completed' || b.status == 'cancelled')
              .toList()
              .reversed;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              const _EarningsCard(),
              if (bookings.isEmpty)
                const _EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No bookings yet',
                  text:
                      'When someone books one of your sessions, it appears '
                      'here to confirm.',
                ),
              if (waiting.isNotEmpty) ...[
                const _SectionTitle('Waiting for you'),
                for (final b in waiting) _ExpertBookingCard(booking: b),
              ],
              if (confirmed.isNotEmpty) ...[
                const _SectionTitle('Confirmed'),
                for (final b in confirmed) _ExpertBookingCard(booking: b),
              ],
              if (past.isNotEmpty) ...[
                const _SectionTitle('Completed and cancelled'),
                for (final b in past) _ExpertBookingCard(booking: b),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Withdrawable earnings and money held for booked sessions, from the
/// server's wallet balances.
class _EarningsCard extends ConsumerWidget {
  const _EarningsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletProvider.select((w) => w.summary));
    String money(double? v) => v == null
        ? '--'
        : NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: v.truncateToDouble() == v ? 0 : 2,
          ).format(v);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Withdrawable earnings',
                  value: money(summary?.withdrawableBalance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Figure(
                  label: 'Held for booked sessions',
                  value: money(summary?.lockedBalance),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/wallet'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('Wallet and payouts'),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpertBookingCard extends ConsumerStatefulWidget {
  const _ExpertBookingCard({required this.booking});

  final BookingItem booking;

  @override
  ConsumerState<_ExpertBookingCard> createState() => _ExpertBookingCardState();
}

class _ExpertBookingCardState extends ConsumerState<_ExpertBookingCard> {
  bool _busy = false;

  BookingItem get b => widget.booking;

  /// "Mark completed" releases the mentee's payment, so it is offered only
  /// once the session has started.
  bool get _hasStarted {
    final at = b.scheduledAt;
    return at != null && !at.isAfter(DateTime.now());
  }

  String get _amountLabel {
    if (b.isFree) return 'Free session';
    final amount = '₹${b.amount.toStringAsFixed(b.amount % 1 == 0 ? 0 : 2)}';
    return switch (b.paymentStatus) {
      'paid' => '$amount · paid, held until completed',
      'refunded' => '$amount · refunded',
      _ => '$amount · payment pending',
    };
  }

  Future<void> _setStatus(String status) async {
    final name = b.menteeName.isNotEmpty ? b.menteeName : 'The mentee';
    final paid = b.paymentStatus == 'paid' && !b.isFree;
    final amount = '₹${b.amount.toStringAsFixed(b.amount % 1 == 0 ? 0 : 2)}';
    final (title, text, action) = switch (status) {
      'completed' => (
        'Mark as completed?',
        paid
            ? 'Do this only after the session has taken place. $amount held '
                  'for it will move to your earnings.'
            : 'Do this only after the session has taken place.',
        'Mark completed',
      ),
      'cancelled' => (
        b.status == 'pending'
            ? 'Decline this booking?'
            : 'Cancel this session?',
        paid
            ? '$name will get $amount back in their wallet.'
            : '$name will be told the session is cancelled.',
        b.status == 'pending' ? 'Decline' : 'Cancel session',
      ),
      _ => (
        'Confirm this booking?',
        '$name will see the session as confirmed. Add a meeting link '
            'before it starts.',
        'Confirm',
      ),
    };
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: status == 'cancelled'
                  ? AppColors.error
                  : AppColors.brandNavy,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final error = await ref
        .read(expertDashboardActionsProvider)
        .setBookingStatus(b, status);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      error ??
          switch (status) {
            'completed' => 'Session completed.',
            'cancelled' => 'Session cancelled.',
            _ => 'Booking confirmed.',
          },
      isError: error != null,
    );
  }

  Future<void> _editLink() async {
    final link = await showMeetingLinkSheet(context, initial: b.meetingLink);
    if (link == null || !mounted) return;
    setState(() => _busy = true);
    final error = await ref
        .read(expertDashboardActionsProvider)
        .setMeetingLink(b, link);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(error ?? 'Meeting link saved.', isError: error != null);
  }

  Future<void> _openLink() async {
    final uri = Uri.tryParse(b.meetingLink);
    var opened = false;
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!opened && mounted) _toast('Could not open the meeting link.');
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at = b.scheduledAt;
    final when = at == null
        ? 'Time not set'
        : DateFormat('EEE, d MMM · h:mm a').format(at);
    final name = b.menteeName.isNotEmpty ? b.menteeName : 'KaamMilega member';
    final title = b.mentorshipTitle.isNotEmpty
        ? b.mentorshipTitle
        : 'Mentorship session';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.moduleExpertsLight,
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.moduleExperts,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: b.status),
            ],
          ),
          const SizedBox(height: 10),
          _InfoLine(icon: Icons.schedule_rounded, text: when),
          _InfoLine(icon: Icons.currency_rupee_rounded, text: _amountLabel),
          if (b.notes.isNotEmpty)
            _InfoLine(icon: Icons.notes_rounded, text: 'Note: ${b.notes}'),
          if (b.status == 'confirmed' && b.meetingLink.isNotEmpty)
            _InfoLine(icon: Icons.videocam_outlined, text: b.meetingLink),
          if (b.status == 'pending' || b.status == 'confirmed') ...[
            const SizedBox(height: 10),
            if (_busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else if (b.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setStatus('cancelled'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _setStatus('confirmed'),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editLink,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text(
                        b.meetingLink.isEmpty
                            ? 'Add meeting link'
                            : 'Edit link',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (b.meetingLink.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openLink,
                        icon: const Icon(Icons.videocam_outlined, size: 18),
                        label: const Text(
                          'Join',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _hasStarted ? () => _setStatus('completed') : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark completed'),
              ),
              if (!_hasStarted)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'You can mark it completed once the session has started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => _setStatus('cancelled'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Cancel session'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Asks for a meeting link; returns it (not yet sent) or null if closed.
Future<String?> showMeetingLinkSheet(
  BuildContext context, {
  String initial = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _MeetingLinkSheet(initial: initial),
  );
}

class _MeetingLinkSheet extends StatefulWidget {
  const _MeetingLinkSheet({required this.initial});

  final String initial;

  @override
  State<_MeetingLinkSheet> createState() => _MeetingLinkSheetState();
}

class _MeetingLinkSheetState extends State<_MeetingLinkSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final link = ExpertRepository.normalizeMeetingLink(_controller.text);
    if (link == null) {
      setState(
        () => _error = 'Please enter a valid link, for example meet.google.com/abc-defg-hij',
      );
      return;
    }
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Meeting link',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste the Google Meet, Zoom or Teams link for this session.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: InputDecoration(
              hintText: 'https://meet.google.com/...',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _save, child: const Text('Save link')),
        ],
      ),
    );
  }
}

// --- My sessions ------------------------------------------------------------

class _OfferingsTab extends ConsumerWidget {
  const _OfferingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOfferingsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myOfferingsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          ElevatedButton.icon(
            onPressed: () => showExpertOfferingSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a session'),
          ),
          const SizedBox(height: 14),
          ...async.when(
            loading: () => const [
              SizedBox(
                height: 300,
                child: ShimmerLoadingList(count: 2, itemHeight: 120),
              ),
            ],
            error: (e, _) => [
              SizedBox(
                height: 320,
                child: NetworkStateView.fromError(
                  e,
                  onRetry: () => ref.invalidate(myOfferingsProvider),
                ),
              ),
            ],
            data: (offerings) => offerings.isEmpty
                ? const [
                    _EmptyState(
                      icon: Icons.co_present_outlined,
                      title: 'No sessions yet',
                      text:
                          'Create a session so people can find and book you '
                          'on the Experts page.',
                    ),
                  ]
                : [for (final o in offerings) _OfferingCard(offering: o)],
          ),
        ],
      ),
    );
  }
}

class _OfferingCard extends ConsumerWidget {
  const _OfferingCard({required this.offering});

  final ExpertOffering offering;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this session?'),
        content: Text(
          '"${offering.title}" will no longer be shown to people. Sessions '
          'already booked are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await ref
        .read(expertDashboardActionsProvider)
        .deleteOffering(offering);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Session deleted.'),
        backgroundColor: error != null ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = offering;
    final price = o.isFree
        ? 'Free'
        : '₹${o.price.toStringAsFixed(o.price % 1 == 0 ? 0 : 2)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (o.category.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.moduleExpertsLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      o.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.moduleExperts,
                      ),
                    ),
                  ),
                Text(
                  o.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (o.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    o.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      text: '${o.durationMinutes} min',
                    ),
                    _InfoChip(icon: Icons.sell_outlined, text: price),
                    if (o.reviews > 0)
                      _InfoChip(
                        icon: Icons.star_rounded,
                        text: '${o.rating.toStringAsFixed(1)} (${o.reviews})',
                      ),
                    if (!o.isActive)
                      const _InfoChip(
                        icon: Icons.visibility_off_outlined,
                        text: 'Hidden',
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Session options',
            onSelected: (v) {
              if (v == 'edit') {
                showExpertOfferingSheet(context, editing: o);
              } else {
                _delete(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Small pieces -----------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('New', AppColors.warning),
      'confirmed' => ('Confirmed', AppColors.blue),
      'completed' => ('Completed', AppColors.success),
      'cancelled' => ('Cancelled', AppColors.error),
      _ => (status, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textLight),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.moduleExperts),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
