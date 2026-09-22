import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import 'shimmer_loading.dart';

/// Reusable widget for presenting consistent API screen states:
/// Loading, Success, Empty, Offline, and Error with Retry.
class NetworkStateView extends StatelessWidget {
  final bool isLoading;
  final bool isOffline;
  final String? errorMessage;
  final bool isEmpty;
  final Widget? loadingWidget;
  final Widget child;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;
  final DateTime? cachedTimestamp;

  const NetworkStateView({
    super.key,
    required this.child,
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.isEmpty = false,
    this.loadingWidget,
    this.onRetry,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyAction,
    this.cachedTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingWidget ??
          const ShimmerLoadingList(count: 4, itemHeight: 90);
    }

    if (isOffline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFE11D48),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Unable to Load Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  color: Color(0xFF94A3B8),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle ?? 'No Records Found',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (emptyMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  emptyMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
              if (emptyAction != null) ...[
                const SizedBox(height: 20),
                emptyAction!,
              ],
            ],
          ),
        ),
      );
    }

    if (cachedTimestamp != null) {
      return Column(
        children: [
          CachedDataBadge(timestamp: cachedTimestamp!),
          Expanded(child: child),
        ],
      );
    }

    return child;
  }
}

/// Subtle badge indicating that data is served from local cache with timestamp
class CachedDataBadge extends StatelessWidget {
  final DateTime timestamp;

  const CachedDataBadge({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMM d, h:mm a').format(timestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFFFEF3C7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 14, color: Color(0xFF92400E)),
          const SizedBox(width: 6),
          Text(
            'Showing saved data (Updated: $formatted)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}
