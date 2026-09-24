import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import 'shimmer_loading.dart';
import 'fade_slide_in.dart';

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
    // Smooth cross-fade when switching between loading / error / empty /
    // content (the content itself is not rebuilt differently).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey(_stateKey), child: _buildState()),
    );
  }

  String get _stateKey {
    if (isLoading) return 'loading';
    if (isOffline) return 'offline';
    if (errorMessage != null && errorMessage!.isNotEmpty) return 'error';
    if (isEmpty) return 'empty';
    return 'content';
  }

  Widget _buildState() {
    if (isLoading) {
      return loadingWidget ??
          const ShimmerLoadingList(count: 4, itemHeight: 90);
    }

    if (isOffline) {
      return _StateMessage(
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFFE11D48),
        iconBackground: const Color(0xFFFEF2F2),
        iconBorder: const Color(0xFFFECACA),
        title: 'No Internet Connection',
        message: 'Please check your internet connection and try again.',
        action: onRetry == null ? null : _RetryButton(onRetry: onRetry!),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFD97706),
        iconBackground: const Color(0xFFFFFBEB),
        iconBorder: const Color(0xFFFDE68A),
        title: 'Unable to Load Data',
        message: errorMessage!,
        action: onRetry == null ? null : _RetryButton(onRetry: onRetry!),
      );
    }

    if (isEmpty) {
      return _StateMessage(
        icon: Icons.inbox_rounded,
        iconColor: const Color(0xFF94A3B8),
        iconBackground: const Color(0xFFF1F5F9),
        title: emptyTitle ?? 'No Records Found',
        message: emptyMessage,
        action: emptyAction,
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

/// Shared layout for the offline / error / empty states: soft round icon,
/// bold title, readable message and an optional action. Scrolls instead of
/// overflowing on small screens or with large font settings.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.iconBorder,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color? iconBorder;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: FadeSlideIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        shape: BoxShape.circle,
                        border: iconBorder == null
                            ? null
                            : Border.all(color: iconBorder!),
                      ),
                      child: Icon(icon, color: iconColor, size: 38),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                    if (message != null && message!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF64748B),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: 24),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text(
        'Retry',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
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
          Flexible(
            child: Text(
            'Showing saved data (Updated: $formatted)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
