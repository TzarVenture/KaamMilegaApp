/// Reasons accepted by the backend for a refund request (km-backend
/// `wallet.DisputeReason`).
enum DisputeReason {
  sessionCancelled('session_cancelled', 'Session was cancelled'),
  serviceNotProvided('service_not_provided', 'Service was not provided'),
  duplicateCharge('duplicate_charge', 'Charged more than once'),
  technicalFailure('technical_failure', 'Technical problem'),
  dissatisfied('dissatisfied', 'Not satisfied'),
  other('other', 'Other');

  const DisputeReason(this.value, this.label);

  final String value;
  final String label;

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
