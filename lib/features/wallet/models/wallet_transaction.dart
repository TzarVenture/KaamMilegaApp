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

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Transaction',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.fromString(json['type']?.toString()),
      status: TransactionStatus.fromString(json['status']?.toString()),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      referenceId: json['reference_id']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      category: json['category']?.toString(),
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
