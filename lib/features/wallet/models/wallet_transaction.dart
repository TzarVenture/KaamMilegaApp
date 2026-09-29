enum TransactionType {
  credit,
  debit;

  static TransactionType fromString(String? type) {
    if (type?.toLowerCase() == 'credit') return TransactionType.credit;
    return TransactionType.debit;
  }

  String get label => this == TransactionType.credit ? 'Credit' : 'Debit';
}

enum TransactionStatus {
  completed,
  pending,
  failed;

  static TransactionStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
        return TransactionStatus.completed;
      case 'failed':
      case 'reversed':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }
}

class WalletTransaction {
  final String id;
  final String title;
  final String description;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? referenceId;
  final String? paymentMethod;
  final String? category;

  /// Which balance moved: main, earnings, locked or bonus.
  final String? targetBalance;

  /// That balance right after this entry (from the server), if sent.
  final double? balanceAfter;

  const WalletTransaction({
    required this.id,
    required this.title,
    this.description = '',
    required this.amount,
    required this.type,
    this.status = TransactionStatus.completed,
    required this.createdAt,
    this.referenceId,
    this.paymentMethod,
    this.category,
    this.targetBalance,
    this.balanceAfter,
  });

  bool get isCredit => type == TransactionType.credit;

  /// The server's own description ("InstantPass Activation (10 Spot
  /// Gigs)") when it sent one, otherwise the readable category name.
  String get displayTitle =>
      description.trim().isNotEmpty ? description.trim() : title;

  /// "Main balance", "Earnings", "Locked balance", "Bonus balance".
  String? get balanceLabel => switch (targetBalance) {
    'main' => 'Main balance',
    'earnings' => 'Earnings',
    'locked' => 'Locked balance',
    'bonus' => 'Bonus balance',
    _ => null,
  };

  /// Short reference shown on the row ("#1dd2703a"): the payment or
  /// booking reference when there is one, else the entry id.
  String get shortReference {
    final ref = (referenceId ?? '').trim().isNotEmpty
        ? referenceId!.trim()
        : id;
    if (ref.isEmpty) return '';
    return '#${ref.length > 8 ? ref.substring(ref.length - 8) : ref}';
  }

  /// One plain sentence on what the money was for.
  String get purpose {
    switch (category) {
      case 'topup':
        return 'Money you added to your wallet.';
      case 'pass_purchase':
        return 'Paid for an InstantPass, which lets you go online and claim '
            'spot gigs.';
      case 'session_booking':
        if (targetBalance == 'earnings') {
          return 'Earnings from a mentorship session you gave.';
        }
        if (targetBalance == 'locked') {
          return isCredit
              ? 'Payment for a mentorship booking, held safely until the '
                    'session is completed.'
              : 'Held payment released after the mentorship session.';
        }
        return 'Paid for a mentorship session booking.';
      case 'session_payout':
        return 'Earnings from a mentorship session.';
      case 'gig_payout':
        return 'Pay for a spot gig you completed.';
      case 'withdrawal':
        return 'Money sent from your earnings to your bank or UPI.';
      case 'bonus_reward':
        return 'Promotional bonus credit (cannot be withdrawn).';
      case 'refund':
        return 'Money returned to your wallet for an approved refund.';
      case 'subscription':
        return 'Paid for a Pro Expert plan.';
      case 'event_ticket':
        return 'Paid for an event ticket.';
      default:
        return isCredit
            ? 'Money added to your wallet.'
            : 'Money paid from your wallet.';
    }
  }

  /// Readable title for backend ledger categories (backend has no "title")
  static String titleForCategory(String? category) {
    switch (category) {
      case 'topup':
        return 'Wallet top-up';
      case 'pass_purchase':
        return 'InstantPass purchase';
      case 'session_booking':
        return 'Mentorship session booking';
      case 'session_payout':
        return 'Mentorship session earning';
      case 'gig_payout':
        return 'Gig payout';
      case 'withdrawal':
        return 'Withdrawal';
      case 'bonus_reward':
        return 'Bonus reward';
      case 'refund':
        return 'Refund';
      case 'subscription':
        return 'Expert subscription';
      case 'event_ticket':
        return 'Event ticket';
      default:
        return 'Transaction';
    }
  }

  /// Same rule as the backend (F73): a refund can be requested on a debit
  /// payment, but not on a refund.
  bool get canRequestRefund =>
      id.isNotEmpty && type == TransactionType.debit && category != 'refund';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString();
    return WalletTransaction(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? titleForCategory(category),
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.fromString(json['type']?.toString()),
      status: TransactionStatus.fromString(json['status']?.toString()),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      referenceId: json['reference_id']?.toString(),
      paymentMethod:
          json['payment_method']?.toString() ??
          (json['metadata'] is Map
              ? (json['metadata'] as Map)['payment_channel']?.toString()
              : null),
      category: category,
      targetBalance: json['target_balance']?.toString(),
      balanceAfter: json['balance_after'] is num
          ? (json['balance_after'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (referenceId != null) 'reference_id': referenceId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (category != null) 'category': category,
      if (targetBalance != null) 'target_balance': targetBalance,
      if (balanceAfter != null) 'balance_after': balanceAfter,
    };
  }
}
