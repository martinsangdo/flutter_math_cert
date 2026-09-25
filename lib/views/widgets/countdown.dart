import 'dart:async';

import 'package:flutter/material.dart';

String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Ticks once a second and rebuilds only what [builder] returns, so the rest of
/// the screen is untouched by the timer.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.deadline,
    required this.builder,
    this.onDone,
  });

  final DateTime deadline;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final VoidCallback? onDone;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late Duration _remaining = _left();
  Timer? _timer;

  Duration _left() {
    final d = widget.deadline.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _remaining = _left());
        if (_remaining == Duration.zero) {
          _timer?.cancel();
          widget.onDone?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
