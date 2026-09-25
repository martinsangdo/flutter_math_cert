import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Plain text with inline LaTeX between `$...$`, e.g. `Solve $x^2 = 49$.`
class LatexText extends StatelessWidget {
  const LatexText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final parts = text.split(r'$');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              if (i.isEven)
                TextSpan(text: parts[i])
              else
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Math.tex(
                    parts[i],
                    textStyle: base,
                    onErrorFallback: (_) => Text(parts[i], style: base),
                  ),
                ),
        ],
      ),
    );
  }
}

/// A standalone LaTeX expression (no `$` delimiters), scrollable sideways when
/// wider than the screen.
class LatexBlock extends StatelessWidget {
  const LatexBlock(this.tex, {super.key});

  final String tex;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        mathStyle: MathStyle.display,
        textStyle: style,
        onErrorFallback: (_) => Text(tex, style: style),
      ),
    );
  }
}
