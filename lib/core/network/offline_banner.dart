import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_provider.dart';
import 'network_status.dart';

/// Non-blocking animated overlay displaying network status banner across the app
class OfflineBannerOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineBannerOverlay({super.key, required this.child});

  @override
  ConsumerState<OfflineBannerOverlay> createState() =>
      _OfflineBannerOverlayState();
}

class _OfflineBannerOverlayState extends ConsumerState<OfflineBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  NetworkStatus _previousStatus = NetworkStatus.online;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleStatusChange(NetworkStatus next) {
    if (_previousStatus == NetworkStatus.offline &&
        next == NetworkStatus.online) {
      // Reconnected! Show "Back Online" briefly
      setState(() {
        _showBackOnline = true;
      });
      _animController.forward();

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _showBackOnline) {
          _animController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showBackOnline = false;
              });
            }
          });
        }
      });
    } else if (next == NetworkStatus.offline) {
      setState(() {
        _showBackOnline = false;
      });
      _animController.forward();
    } else if (next == NetworkStatus.online && !_showBackOnline) {
      _animController.reverse();
    }
    _previousStatus = next;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkStatus>(networkStatusProvider, (_, next) {
      _handleStatusChange(next);
    });

    final currentStatus = ref.watch(networkStatusProvider);
    final isOffline = currentStatus == NetworkStatus.offline;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: SlideTransition(
              position: _slideAnimation,
              child: isOffline || _showBackOnline
                  ? Material(
                      type: MaterialType.transparency,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _showBackOnline
                              ? const Color(0xFF059669) // Emerald green
                              : const Color(0xFF1E293B), // Slate dark
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: _showBackOnline
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE11D48)
                                      .withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showBackOnline
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showBackOnline
                                        ? 'Back Online'
                                        : 'No Internet Connection',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (!_showBackOnline)
                                    const Text(
                                      'Some features may be unavailable. Showing saved data.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!_showBackOnline)
                              InkWell(
                                onTap: () {
                                  ref
                                      .read(networkStatusProvider.notifier)
                                      .refresh();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Check',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
