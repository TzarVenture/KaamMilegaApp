/// Wallet balances from GET /wallet/balance (backend WalletSummaryResponse).
class WalletSummary {
  final String walletId;
  final double totalBalance; // main + earnings + bonus
  final double withdrawableBalance; // earnings only
  final double mainBalance; // money added by the user
  final double earningsBalance; // money earned (withdrawable)
  final double lockedBalance; // held in escrow for active sessions/tasks
  final double bonusBalance; // promotional credits (not withdrawable)
  final String currency;
  final String status; // active / suspended / frozen
  final DateTime? updatedAt;

  const WalletSummary({
    this.walletId = '',
    this.totalBalance = 0,
    this.withdrawableBalance = 0,
    this.mainBalance = 0,
    this.earningsBalance = 0,
    this.lockedBalance = 0,
    this.bonusBalance = 0,
    this.currency = 'INR',
    this.status = 'active',
    this.updatedAt,
  });

  static double _num(dynamic v) => (v is num) ? v.toDouble() : 0.0;

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
    walletId: json['wallet_id']?.toString() ?? '',
    totalBalance: _num(json['total_balance']),
    withdrawableBalance: _num(json['withdrawable_balance']),
    mainBalance: _num(json['main_balance']),
    earningsBalance: _num(json['earnings_balance']),
    lockedBalance: _num(json['locked_balance']),
    bonusBalance: _num(json['bonus_balance']),
    currency: json['currency']?.toString() ?? 'INR',
    status: json['status']?.toString() ?? 'active',
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'wallet_id': walletId,
    'total_balance': totalBalance,
    'withdrawable_balance': withdrawableBalance,
    'main_balance': mainBalance,
    'earnings_balance': earningsBalance,
    'locked_balance': lockedBalance,
    'bonus_balance': bonusBalance,
    'currency': currency,
    'status': status,
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  bool get isActive => status == 'active';
}

/// Razorpay order created by the backend (wallet top-up or paid booking).
class PaymentOrder {
  final String orderId;
  final double amount; // INR
  final int amountPaise;
  final String currency;
  final String keyId; // Razorpay public key id sent by the server
  final String bookingId; // only for mentorship bookings

  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.amountPaise,
    required this.keyId,
    this.currency = 'INR',
    this.bookingId = '',
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] is num)
        ? (json['amount'] as num).toDouble()
        : 0.0;
    final paise = (json['amount_paise'] is num)
        ? (json['amount_paise'] as num).toInt()
        : (amount * 100).round();
    return PaymentOrder(
      orderId: json['order_id']?.toString() ?? '',
      amount: amount,
      amountPaise: paise,
      currency: json['currency']?.toString() ?? 'INR',
      keyId: json['key_id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
    );
  }

  bool get isValid => orderId.isNotEmpty && keyId.isNotEmpty && amountPaise > 0;
}
