import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathpathway_junior/views/widgets/latex_text.dart';

// Stem as stored for SASMO grade 4, practice 1, question 4.
const _stem =
    r'In the addition problem below, different letters represent different '
    r'digits from 0 to 9:\n\n\begin{array}{r@{\quad}l@{}l@{}l} & A & B & C \\ '
    r'+ & A & B & C \\ \hline & C & D & B \end{array}\nFind the 3-digit number $ABC$.';

void main() {
  test('parseLatexText pulls a bare array out as display math', () {
    final parts = parseLatexText(_stem);
    final blocks = parts.where((p) => p.block).toList();
    expect(blocks, hasLength(1));
    expect(blocks.single.text, startsWith(r'\begin{array}{r'));
    expect(blocks.single.text, isNot(contains('@')));
    expect(parts.where((p) => !p.math).map((p) => p.text).join(),
        isNot(contains(r'\n')));
    expect(parts.where((p) => p.math && !p.block).single.text, 'ABC');
  });

  testWidgets('bare array renders as math, not raw text', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LatexText(_stem))));
    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining('begin'), findsNothing);
  });
}
