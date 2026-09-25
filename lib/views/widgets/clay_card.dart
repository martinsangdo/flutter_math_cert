import 'package:flutter/material.dart';

/// Chunky card: thick border and a solid "lip" underneath. Cheap to paint (no
/// blur), and it gives the app its toy-like feel. Tappable when [onTap] is set.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = 2,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.selected,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Exposed to screen readers as the selected state of a choice.
  final bool? selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = borderColor ?? scheme.outlineVariant;
    final shape = BorderRadius.circular(radius);

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: border, width: borderWidth),
        boxShadow: [BoxShadow(color: border, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius - borderWidth),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );

    if (onTap != null) {
      card = Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: card,
      );
    }
    // Room for the bottom lip so neighbours don't touch it.
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: card);
  }
}
