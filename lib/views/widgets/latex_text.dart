import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A `\begin{env}...\end{env}` block (arrays, matrices) written outside `$...$`.
final _bareEnv = RegExp(r'\\begin\{(\w+\*?)\}[\s\S]*?\\end\{\1\}');

/// `@{...}` column separators in an `array` spec; the math library rejects them.
final _atCol = RegExp(r'@\{[^{}]*\}');

// Some stems omit math delimiters around multiplication (e.g. 6\times4).
// Match the complete command, without changing longer command names.
final _bareTimes = RegExp(r'\\times(?![a-zA-Z])');

/// A piece of question text: plain text, inline math, or display math.
@visibleForTesting
typedef LatexPart = ({String text, bool math, bool block});

/// Decode an extra escaping layer only when the environment marker proves
/// one is present. Ordinary TeX uses double slashes for row breaks.
String _normalizeLatex(String text) {
  if (text.contains(r'\\begin{')) {
    text = text.replaceAll(r'\\', r'\');
  }
  // Some generated solutions put prose directly in aligned and prefix each
  // sentence with a slash instead of using \text{...}. Recover those blocks
  // as wrapping prose with individual math expressions, not one giant formula.
  final proseRow = RegExp(r'\\(If|Then|Thus|Conversely|Summing|Hence)\b');
  text = text.replaceAllMapped(
    RegExp(r'\\\[\s*(\\begin\{aligned\}[\s\S]*?\\end\{aligned\})\s*\\\]'),
    (m) => proseRow.hasMatch(m[1]!) ? m[1]! : m[0]!,
  );
  text = text.replaceAllMapped(_bareEnv, (match) {
    final source = match[0]!;
    if (match[1] != 'aligned' || !proseRow.hasMatch(source)) return source;
    var body = source
        .replaceFirst(r'\begin{aligned}', '')
        .replaceFirst(r'\end{aligned}', '')
        .replaceAllMapped(proseRow, (m) => '\n${m[1]}')
        .replaceAll(RegExp(r'\\n(?=[A-Z\\])'), '\n')
        .replaceAll(r'\ ', ' ')
        .replaceAll('&', '');
    final expression = RegExp(
      r'[A-Za-z0-9]+(?:[_^](?:\{[^{}]*\}|[A-Za-z0-9]))*'
      r'(?:(?:[=+−-]|\\(?:equiv|neq|ne|mid|nmid)\s*)'
      r'[A-Za-z0-9]+(?:[_^](?:\{[^{}]*\}|[A-Za-z0-9]))*'
      r'|\\(?:pmod|phi)\{[^{}]*\})*',
    );
    final lines = body.split('\n');
    body = lines
        .map((line) {
          if (line.contains(r'\frac')) return '\$${line.trim()}\$';
          return line
              .replaceAllMapped(expression, (m) {
                final value = m[0]!;
                return RegExp(r'[_^=\\]').hasMatch(value)
                    ? '\$$value\$'
                    : value;
              })
              .replaceAll(r'\phi', r'$\phi$');
        })
        .join('\n');
    return body;
  });
  return text;
}

String _mathSource(String text) =>
    text.replaceAll(_atCol, '').replaceAll(RegExp(r'\\n(?=[A-Z\\])'), '\n');

/// Splits [text] into parts. Content authors store newlines as a literal `\n`
/// and leave array environments outside `$...$`; both are handled here.
@visibleForTesting
List<LatexPart> parseLatexText(String text) {
  text = _normalizeLatex(text);
  final parts = <LatexPart>[];
  void plain(String t) {
    // Decode stored line breaks without corrupting commands such as \neq.
    t = t.replaceAll(RegExp(r'\\newline\b|\\n(?![a-z])'), '\n');
    final lines = t.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      // Outside math delimiters, \text{...} is prose and should wrap naturally.
      while (line.isNotEmpty) {
        final start = line.indexOf(r'\text{');
        if (start < 0) {
          final formula = line.trim();
          final math = RegExp(
            r'^\\(?:frac|dfrac|tfrac|binom|sqrt|sum|prod|int)\b',
          ).hasMatch(formula);
          parts.add((
            text: math ? formula : line.replaceAll(_bareTimes, '×'),
            math: math,
            block: math,
          ));
          break;
        }
        var depth = 1;
        var end = start + 6;
        while (end < line.length && depth > 0) {
          if (line[end] == '{') depth++;
          if (line[end] == '}') depth--;
          end++;
        }
        if (depth != 0) {
          parts.add((text: line, math: false, block: false));
          break;
        }
        if (start > 0) plain(line.substring(0, start));
        parts.add((
          text: line.substring(start + 6, end - 1),
          math: false,
          block: false,
        ));
        line = line.substring(end);
      }
      if (i < lines.length - 1) {
        parts.add((text: '\n', math: false, block: false));
      }
    }
  }

  void outsideMath(String piece) {
    var last = 0;
    for (final m in _bareEnv.allMatches(piece)) {
      plain(piece.substring(last, m.start));
      parts.add((text: _mathSource(m[0]!), math: true, block: true));
      last = m.end;
    }
    plain(piece.substring(last));
  }

  // Recognize paired delimiters rather than splitting on every dollar sign.
  final delimited = RegExp(
    r'\$\$([\s\S]*?)\$\$|\\\[([\s\S]*?)\\\]|\\\(([\s\S]*?)\\\)|\$([^$]*?)\$',
  );
  var last = 0;
  for (final match in delimited.allMatches(text)) {
    outsideMath(text.substring(last, match.start));
    final formula = match[1] ?? match[2] ?? match[3] ?? match[4]!;
    parts.add((
      text: _mathSource(formula),
      math: true,
      block: match[1] != null || match[2] != null,
    ));
    last = match.end;
  }
  outsideMath(text.substring(last));
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
    return LayoutBuilder(
      builder: (context, constraints) => Text.rich(
        TextSpan(
          style: base,
          children: [
            for (final p in parseLatexText(text))
              if (!p.math)
                TextSpan(text: p.text)
              else
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Math.tex(
                        p.text,
                        mathStyle: p.block ? MathStyle.display : MathStyle.text,
                        textStyle: base,
                        onErrorFallback: (_) => Text(p.text, style: base),
                      ),
                    ),
                  ),
                ),
          ],
        ),
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
