import 'dart:async';

import 'package:flutter/material.dart';

String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatDaysLeft(Duration d) {
  final h = (d.inHours % 24).toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inDays}d ${h}h ${m}m ${s}s';
}

/// Ticks once a second and rebuilds only this Text, so the rest of the screen
/// is untouched by the timer.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.deadline,
    required this.format,
    this.onDone,
    this.style,
  });

  final DateTime deadline;
  final String Function(Duration remaining) format;
  final VoidCallback? onDone;
  final TextStyle? style;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
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
  Widget build(BuildContext context) =>
      Text(widget.format(_remaining), style: widget.style);
}
