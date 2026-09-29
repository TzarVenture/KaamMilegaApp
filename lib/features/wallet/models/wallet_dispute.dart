/// Reasons accepted by the backend for a refund request (km-backend
/// `wallet.DisputeReason`).
/// Labels and hints are the same as on the website.
enum DisputeReason {
  serviceNotProvided(
    'service_not_provided',
    'Service / Mentorship Not Delivered',
    'The session did not take place or the mentor was absent',
  ),
  sessionCancelled(
    'session_cancelled',
    'Session Cancelled',
    'The scheduled session or booking was cancelled',
  ),
  duplicateCharge(
    'duplicate_charge',
    'Duplicate Deduction',
    'The amount was deducted more than once',
  ),
  technicalFailure(
    'technical_failure',
    'Technical Failure',
    'A technical problem or disconnection prevented delivery',
  ),
  dissatisfied(
    'dissatisfied',
    'Quality / Dissatisfied',
    'The quality did not meet what was agreed',
  ),
  other(
    'other',
    'Other Reason',
    'Any other issue that needs a refund or review',
  );

  const DisputeReason(this.value, this.label, this.hint);

  final String value;
  final String label;

  /// One line under the chosen reason.
  final String hint;

  static DisputeReason? fromValue(String? value) {
    for (final r in values) {
      if (r.value == value) return r;
    }
    return null;
  }
}

/// Review state of a refund request.
enum DisputeStatus {
  pending('pending', 'Submitted'),
  underReview('under_review', 'Under review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const DisputeStatus(this.value, this.label);

  final String value;
  final String label;

  static DisputeStatus fromValue(String? value) {
    for (final s in values) {
      if (s.value == value) return s;
    }
    return DisputeStatus.pending;
  }

  bool get isOpen => this == pending || this == underReview;
}

/// A refund request raised on a wallet payment (km-backend
/// `wallet.WalletDispute`, feature F73). An approved request is refunded by
/// the server as a "refund" credit in the wallet.
class WalletDispute {
  final String id;
  final String transactionId;
  final String referenceId;
  final double amount;

  /// Ledger category of the disputed payment, e.g. event_ticket.
  final String category;

  /// Raw reason from the server; [reason] is null for unknown values.
  final String reasonValue;
  final DisputeReason? reason;
  final String description;
  final DisputeStatus status;
  final String adminNotes;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const WalletDispute({
    required this.id,
    required this.transactionId,
    this.referenceId = '',
    this.amount = 0,
    this.category = '',
    this.reasonValue = '',
    this.reason,
    this.description = '',
    this.status = DisputeStatus.pending,
    this.adminNotes = '',
    this.createdAt,
    this.resolvedAt,
  });

  factory WalletDispute.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString() ?? '';
    final reason = str('reason');
    return WalletDispute(
      id: str('id').isNotEmpty ? str('id') : str('_id'),
      transactionId: str('transaction_id'),
      referenceId: str('reference_id'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: str('category'),
      reasonValue: reason,
      reason: DisputeReason.fromValue(reason),
      description: str('description'),
      status: DisputeStatus.fromValue(str('status')),
      adminNotes: str('admin_notes'),
      createdAt: DateTime.tryParse(str('created_at')),
      resolvedAt: DateTime.tryParse(str('resolved_at')),
    );
  }

  String get reasonLabel => reason?.label ?? reasonValue;
}
