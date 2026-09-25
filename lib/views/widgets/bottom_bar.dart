import 'package:flutter/material.dart';

import 'content_width.dart';

/// Fixed action bar for the bottom of a screen, safe-area aware. [footer] sits
/// under the actions (used for the banner ad).
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContentWidth(
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: child),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
