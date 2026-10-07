import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/event.dart';

/// Events tab pricing filter, same choices as the website.
enum EventPricingFilter {
  all('All Events'),
  free('Free Events'),
  paid('Paid Masterclasses');

  const EventPricingFilter(this.label);

  final String label;

  /// Uses the same rule as ticket checkout ([EventItem.requiresPayment]):
  /// an event is paid only when it is marked paid AND has a price, so events
  /// saved before paid tickets existed count as free.
  bool matches(EventItem event) {
    switch (this) {
      case EventPricingFilter.all:
        return true;
      case EventPricingFilter.free:
        return !event.requiresPayment;
      case EventPricingFilter.paid:
        return event.requiresPayment;
    }
  }
}

/// Row of pricing chips under the Events search bar. Scrolls sideways on
/// narrow screens or with large text instead of overflowing.
class EventPricingChips extends StatelessWidget {
  const EventPricingChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });

  final EventPricingFilter selected;
  final ValueChanged<EventPricingFilter> onChanged;

  /// Optional extra chip at the end of the row (the sort chip).
  final Widget? trailing;

  /// The server's `is_paid` value for [filter] (null: all events).
  static bool? isPaidParam(EventPricingFilter filter) => switch (filter) {
    EventPricingFilter.all => null,
    EventPricingFilter.free => false,
    EventPricingFilter.paid => true,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            for (final filter in EventPricingFilter.values) ...[
              _PricingChip(
                filter: filter,
                selected: filter == selected,
                onTap: () => onChanged(filter),
              ),
              if (filter != EventPricingFilter.values.last)
                const SizedBox(width: 8),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _PricingChip extends StatelessWidget {
  const _PricingChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final EventPricingFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    final Widget? leading = switch (filter) {
      EventPricingFilter.all => null,
      EventPricingFilter.free => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: selected ? Colors.white : AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
      EventPricingFilter.paid => Icon(
        Icons.confirmation_number_outlined,
        size: 16,
        color: foreground,
      ),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: filter.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 7)],
                Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
