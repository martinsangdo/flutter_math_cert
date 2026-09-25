import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.asset(
            'assets/icon/icon.png',
            width: size,
            height: size,
            cacheWidth: (size * 3).round(), // decode small; the source is 512px
          ),
        ),
      );
}
