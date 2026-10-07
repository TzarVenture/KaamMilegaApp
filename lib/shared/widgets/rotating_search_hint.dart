import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Search box hint where the start stays and the quoted example changes
/// every few seconds, sliding up: Search for 'Jobs' -> 'Companies' -> ...
///
/// Use as `InputDecoration.hint` (shown only while the box is empty).
/// Screen readers hear one fixed [semanticLabel]. With "remove
/// animations" on, the first example stays still.
class RotatingSearchHint extends StatefulWidget {
  const RotatingSearchHint({
    super.key,
    required this.examples,
    required this.semanticLabel,
    this.prefix = 'Search for',
    this.interval = const Duration(milliseconds: 2500),
    this.style,
  });

  final List<String> examples;
  final String semanticLabel;
  final String prefix;
  final Duration interval;
  final TextStyle? style;

  @override
  State<RotatingSearchHint> createState() => _RotatingSearchHintState();
}

class _RotatingSearchHintState extends State<RotatingSearchHint> {
  Timer? _timer;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(RotatingSearchHint old) {
    super.didUpdateWidget(old);
    // The examples can arrive later (for example categories from the
    // server): start or stop rotating to match.
    if (old.examples.length != widget.examples.length ||
        old.interval != widget.interval) {
      _timer?.cancel();
      _timer = null;
      _syncTimer();
    }
  }

  void _syncTimer() {
    final still = MediaQuery.disableAnimationsOf(context);
    if (still || widget.examples.length < 2) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(widget.interval, (_) {
      if (mounted && widget.examples.isNotEmpty) {
        setState(() => _index = (_index + 1) % widget.examples.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same size as the text field's own text; hint colour.
    final style =
        widget.style ??
        DefaultTextStyle.of(context).style
            .copyWith(color: AppColors.textSecondary);
    final example = widget.examples.isEmpty
        ? ''
        : widget.examples[_index % widget.examples.length];
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Row(
        children: [
          Text('${widget.prefix} ', style: style, maxLines: 1),
          Flexible(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) {
                  // New example comes up from below; the old one leaves
                  // upwards.
                  final incoming = child.key == ValueKey(example);
                  final offset = Tween<Offset>(
                    begin: Offset(0, incoming ? 1 : -1),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: offset,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  "'$example'",
                  key: ValueKey(example),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
