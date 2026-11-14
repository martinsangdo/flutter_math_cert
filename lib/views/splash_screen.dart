import 'dart:async';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _started = false;
  bool _finished = false;

  void _startTimer() {
    if (_started) return;
    _started = true;
    // Count the second only once the image has actually been painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _finished = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Image.asset(
            'assets/splash/splash_icon_512x512.png',
            width: 256,
            height: 256,
            fit: BoxFit.contain,
            semanticLabel: 'MathPathway Practice Contest',
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null || wasSynchronouslyLoaded) _startTimer();
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _startTimer();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
