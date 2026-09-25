import 'wallet_summary.dart';

/// Payout destination accepted by km-backend (`payout_method`).
enum PayoutMethod {
  upi('upi'),
  bank('bank');

  const PayoutMethod(this.apiValue);

  /// Exact value the backend expects: "upi" or "bank".
  final String apiValue;
}

/// Body of POST /wallet/withdraw (km-backend `WithdrawalRequest`).
///
/// Backend rules (internal/features/wallet/service.go RequestWithdrawal):
/// amount ₹50 – ₹5,00,000 and not more than the earnings (withdrawable)
/// balance; bank needs `account_number` + `ifsc_code`; UPI needs `upi_id`.
/// `account_holder`, `bank_name` and `phone_number` are optional.
class WithdrawalRequest {
  static const double minAmount = 50;
  static const double maxAmount = 500000;

  final double amount;
  final PayoutMethod method;
  final String accountHolder;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String upiId;
  final String phoneNumber;

  const WithdrawalRequest.upi({
    required this.amount,
    required this.upiId,
    this.accountHolder = '',
    this.phoneNumber = '',
  }) : method = PayoutMethod.upi,
       accountNumber = '',
       ifscCode = '',
       bankName = '';

  const WithdrawalRequest.bank({
    required this.amount,
    required this.accountNumber,
    required this.ifscCode,
    this.accountHolder = '',
    this.bankName = '',
    this.phoneNumber = '',
  }) : method = PayoutMethod.bank,
       upiId = '';

  /// JSON for the backend. Only the fields for the chosen method are sent,
  /// and optional fields only when they have a value.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'amount': amount,
      'payout_method': method.apiValue,
    };
    void putIfPresent(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) json[key] = v;
    }

    putIfPresent('account_holder', accountHolder);
    putIfPresent('phone_number', phoneNumber);
    if (method == PayoutMethod.bank) {
      putIfPresent('account_number', accountNumber);
      putIfPresent('ifsc_code', ifscCode.toUpperCase());
      putIfPresent('bank_name', bankName);
    } else {
      putIfPresent('upi_id', upiId);
    }
    return json;
  }

  /// Destination for confirmation text, with the account number masked.
  String get maskedDestination {
    if (method == PayoutMethod.upi) return 'UPI ${upiId.trim()}';
    final acc = accountNumber.trim();
    final masked = acc.length > 4
        ? '••••${acc.substring(acc.length - 4)}'
        : acc;
    final bank = bankName.trim().isNotEmpty ? bankName.trim() : 'Bank account';
    return '$bank $masked';
  }
}

/// Response of POST /wallet/withdraw (km-backend `WithdrawalResponse`):
/// `{transaction, wallet, message}`. The backend debits the earnings
/// balance when it answers with success.
class WithdrawalResult {
  final String message;

  /// Fresh balances after the debit, when the server sends them.
  final WalletSummary? wallet;

  /// `reference_id` of the ledger entry (e.g. "WTH_…"), when sent.
  final String referenceId;

  const WithdrawalResult({
    required this.message,
    this.wallet,
    this.referenceId = '',
  });

  factory WithdrawalResult.fromJson(dynamic data) {
    if (data is! Map) {
      // Success status without a readable body: the request was accepted.
      return const WithdrawalResult(message: 'Withdrawal request submitted.');
    }
    final map = Map<String, dynamic>.from(data);
    final wallet = map['wallet'];
    final txn = map['transaction'];
    final message = map['message']?.toString().trim() ?? '';
    return WithdrawalResult(
      message: message.isNotEmpty ? message : 'Withdrawal request submitted.',
      wallet: wallet is Map
          ? WalletSummary.fromJson(Map<String, dynamic>.from(wallet))
          : null,
      referenceId: txn is Map ? txn['reference_id']?.toString() ?? '' : '',
    );
  }
}
