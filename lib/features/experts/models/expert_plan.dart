import 'package:intl/intl.dart';

/// A Pro Expert plan from GET /subscriptions/expert/plans (public).
class ExpertPlan {
  final String planType; // "monthly" | "yearly"
  final String name;
  final double price; // INR
  final int durationDays;
  final int savingsPercent;
  final String description;
  final List<String> perks;

  const ExpertPlan({
    required this.planType,
    required this.name,
    required this.price,
    required this.durationDays,
    this.savingsPercent = 0,
    this.description = '',
    this.perks = const [],
  });

  factory ExpertPlan.fromJson(Map<String, dynamic> json) {
    final perks = json['perks'];
    return ExpertPlan(
      planType: json['plan_type']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      price: json['price'] is num ? (json['price'] as num).toDouble() : 0,
      durationDays: json['duration_days'] is num
          ? (json['duration_days'] as num).toInt()
          : 0,
      savingsPercent: json['savings_percent'] is num
          ? (json['savings_percent'] as num).toInt()
          : 0,
      description: json['description']?.toString().trim() ?? '',
      perks: perks is List
          ? perks
                .map((p) => p?.toString().trim() ?? '')
                .where((p) => p.isNotEmpty)
                .toList()
          : const [],
    );
  }

  /// Plans the server can actually sell (it needs the plan type and a price).
  bool get isValid => planType.isNotEmpty && name.isNotEmpty && price > 0;

  bool get isYearly => planType == 'yearly';

  /// "Monthly" / "Annual", used on the upgrade button.
  String get shortName => switch (planType) {
    'monthly' => 'Monthly',
    'yearly' => 'Annual',
    _ => name,
  };

  /// "month", "year" or "N days", from the real plan length.
  String get periodLabel {
    if (durationDays >= 28 && durationDays <= 31) return 'month';
    if (durationDays >= 360 && durationDays <= 366) return 'year';
    return '$durationDays days';
  }

  String get priceLabel => formatRupees(price);

  /// Price per month for yearly plans ("₹375"), otherwise null.
  String? get perMonthLabel =>
      periodLabel == 'year' ? formatRupees(price / 12) : null;
}

/// The signed-in user's plan (GET /subscriptions/expert/my).
class ExpertSubscriptionStatus {
  final bool isActive;
  final String planType;
  final int daysRemaining;
  final DateTime? expiresAt;

  const ExpertSubscriptionStatus({
    required this.isActive,
    this.planType = '',
    this.daysRemaining = 0,
    this.expiresAt,
  });

  static const none = ExpertSubscriptionStatus(isActive: false);

  factory ExpertSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    String planType = json['plan_type']?.toString() ?? '';
    if (planType.isEmpty && sub is Map) {
      planType = sub['plan_type']?.toString() ?? '';
    }
    final expires =
        json['expires_at'] ?? (sub is Map ? sub['expires_at'] : null);
    return ExpertSubscriptionStatus(
      isActive: json['is_active'] == true,
      planType: planType,
      daysRemaining: json['days_remaining'] is num
          ? (json['days_remaining'] as num).toInt()
          : 0,
      expiresAt: expires == null
          ? null
          : DateTime.tryParse(expires.toString())?.toLocal(),
    );
  }

  /// "12 Aug 2027", or empty when the server sent no end date.
  String get expiresLabel =>
      expiresAt == null ? '' : DateFormat('d MMM yyyy').format(expiresAt!);
}

/// "₹4,499" (Indian digit grouping, no paise).
String formatRupees(double amount) =>
    '₹${NumberFormat('#,##,###', 'en_IN').format(amount.round())}';
