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
  });

  /// Readable title for backend ledger categories (backend has no "title")
  static String titleForCategory(String? category) {
    switch (category) {
      case 'topup':
        return 'Wallet top-up';
      case 'pass_purchase':
        return 'Access pass purchase';
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
      default:
        return 'Transaction';
    }
  }

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
    };
  }
}
