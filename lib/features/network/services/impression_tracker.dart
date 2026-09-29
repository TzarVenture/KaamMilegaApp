import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/network_repository.dart';

/// Counts "Post Impressions" the same way as the website (telemetry.tsx):
/// each time a member's card is really seen by another signed-in member,
/// their id is sent to POST /user/impressions. Seen once per card per
/// session, never for the viewer's own card, sent in batches (15 ids, or
/// after 5 seconds, or when the app goes to the background).
class ImpressionTracker with WidgetsBindingObserver {
  ImpressionTracker(
    this._send, {
    required this.selfId,
    this.flushDelay = const Duration(seconds: 5),
  });

  final Future<void> Function(List<String> authorIds) _send;

  /// Signed-in user; null for guests (nothing is recorded).
  final String? selfId;
  final Duration flushDelay;

  static const int batchSize = 15;

  final Set<String> _seen = {};
  final List<String> _buffer = [];
  Timer? _timer;
  bool _disposed = false;

  void record(String authorId, {String? entityId}) {
    final id = authorId.trim();
    if (_disposed || selfId == null || id.isEmpty || id == selfId) return;
    if (!_seen.add(entityId == null ? id : '$id:$entityId')) return;
    _buffer.add(id);
    if (_buffer.length >= batchSize) {
      unawaited(flush());
      return;
    }
    _timer ??= Timer(flushDelay, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty || _disposed) return;
    final batch = _buffer.toSet().toList();
    _buffer.clear();
    try {
      await _send(batch);
    } catch (_) {
      // Background counting only: a failed batch is dropped, as on the
      // website, and never interrupts what the user is doing.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(flush());
    }
  }

  /// On logout or account switch the unsent ids are dropped (the old
  /// session can no longer send them).
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
  }
}

final impressionTrackerProvider = Provider<ImpressionTracker>((ref) {
  final tracker = ImpressionTracker(
    ref.watch(networkRepositoryProvider).recordImpressions,
    selfId: ref.watch(sessionUserIdProvider),
  );
  WidgetsBinding.instance.addObserver(tracker);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(tracker);
    tracker.dispose();
  });
  return tracker;
});

/// Wrap a member's card: once at least half of it has been on screen for
/// about a second (current page, current tab), one impression is recorded
/// for [authorId]. Guests and the user's own card record nothing.
class ImpressionBeacon extends ConsumerStatefulWidget {
  const ImpressionBeacon({
    super.key,
    required this.authorId,
    required this.child,
    this.entityId,
  });

  final String authorId;
  final String? entityId;
  final Widget child;

  @override
  ConsumerState<ImpressionBeacon> createState() => _ImpressionBeaconState();
}

class _ImpressionBeaconState extends ConsumerState<ImpressionBeacon> {
  static const _checkEvery = Duration(milliseconds: 450);

  Timer? _timer;
  int _visibleChecks = 0;

  @override
  void initState() {
    super.initState();
    final self = ref.read(sessionUserIdProvider);
    if (self != null && widget.authorId.isNotEmpty && widget.authorId != self) {
      _timer = Timer.periodic(_checkEvery, (_) => _check());
    }
  }

  void _check() {
    if (!mounted) return;
    if (_isVisible()) {
      // Two checks in a row: on screen for roughly a second.
      if (++_visibleChecks >= 2) {
        ref
            .read(impressionTrackerProvider)
            .record(widget.authorId, entityId: widget.entityId);
        _timer?.cancel();
        _timer = null;
      }
    } else {
      _visibleChecks = 0;
    }
  }

  bool _isVisible() {
    // Hidden tab of the bottom navigation, or a page opened on top
    if (!TickerMode.valuesOf(context).enabled) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final size = box.size;
    if (size.isEmpty) return false;
    final rect = box.localToGlobal(Offset.zero) & size;
    final shown = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
    if (shown.width <= 0 || shown.height <= 0) return false;
    return shown.width * shown.height >= 0.5 * size.width * size.height;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
