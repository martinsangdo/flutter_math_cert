import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A `\begin{env}...\end{env}` block (arrays, matrices) written outside `$...$`.
final _bareEnv = RegExp(r'\\begin\{(\w+\*?)\}[\s\S]*?\\end\{\1\}');

/// `@{...}` column separators in an `array` spec; the math library rejects them.
final _atCol = RegExp(r'@\{[^{}]*\}');

/// A piece of question text: plain text, inline math, or display math.
@visibleForTesting
typedef LatexPart = ({String text, bool math, bool block});

/// Splits [text] into parts. Content authors store newlines as a literal `\n`
/// and leave array environments outside `$...$`; both are handled here.
@visibleForTesting
List<LatexPart> parseLatexText(String text) {
  final parts = <LatexPart>[];
  void plain(String t) {
    t = t.replaceAll(r'\n', '\n');
    if (t.isNotEmpty) parts.add((text: t, math: false, block: false));
  }

  final pieces = text.split(r'$');
  for (var i = 0; i < pieces.length; i++) {
    final piece = pieces[i];
    if (piece.isEmpty) continue;
    if (i.isOdd) {
      parts.add((text: piece, math: true, block: false));
      continue;
    }
    var last = 0;
    for (final m in _bareEnv.allMatches(piece)) {
      plain(piece.substring(last, m.start));
      parts.add((text: m[0]!.replaceAll(_atCol, ''), math: true, block: true));
      last = m.end;
    }
    plain(piece.substring(last));
  }
  return parts;
}

/// Plain text with inline LaTeX between `$...$`, e.g. `Solve $x^2 = 49$.`
class LatexText extends StatelessWidget {
  const LatexText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final p in parseLatexText(text))
            if (!p.math)
              TextSpan(text: p.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Math.tex(
                  p.text,
                  mathStyle: p.block ? MathStyle.display : MathStyle.text,
                  textStyle: base,
                  onErrorFallback: (_) => Text(p.text, style: base),
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
