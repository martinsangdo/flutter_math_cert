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
  const escapedSolution =
      r'\\[\\begin{aligned}\nR_{n}&=\\frac{10^{n}-1}{9}'
      r'\\If n\ is odd, then 10\\equiv1\\pmod{n}\ '
      r'\\Thus 10^{k}\\equiv1\\pmod{n}\ for every k.'
      r'\\Hence R_{n}\ is divisible by n exactly when n\ is odd.'
      r'\\end{aligned}\\]';

  testWidgets('overescaped aligned prose recovers readable text and formulas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 280, child: LatexText(escapedSolution)),
        ),
      ),
    );
    expect(
      find.textContaining('If n is odd', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining(r'\', findRichText: true), findsNothing);
    expect(find.byType(Math), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('valid aligned row breaks and commands are preserved', () {
    const source = r'\begin{aligned}a&=1\\b&=2\end{aligned}';
    expect(parseLatexText(source).single.text, source);
    const escaped = r'\\begin{aligned}a&=1\\\\b&=2\\end{aligned}';
    expect(parseLatexText(escaped).single.text, source);
  });

  const repunitStem =
      r'Let \(R_n\) be the integer consisting of \(n\) '
      r'repeated digit 1 (for example, \(R_4=1111\)). Prove that \(R_n\) '
      r'is divisible by \(n\) if and only if \(n\) is odd.';

  test('parenthesized math in the question stem is parsed inline', () {
    final math = parseLatexText(repunitStem).where((p) => p.math).toList();
    expect(math.map((p) => p.text), ['R_n', 'n', 'R_4=1111', 'R_n', 'n', 'n']);
    expect(math.every((p) => !p.block), isTrue);
  });

  test('mixed inline and display delimiters preserve math styles', () {
    final parts = parseLatexText(r'Use $x$ and \(n\): \[x^2\] or $$n^2$$.');
    expect(parts.where((p) => p.math).map((p) => p.text), [
      'x',
      'n',
      'x^2',
      'n^2',
    ]);
    expect(parts.where((p) => p.block).map((p) => p.text), ['x^2', 'n^2']);
    expect(parseLatexText(r'Unfinished \(n').single.text, r'Unfinished \(n');
  });

  testWidgets('repunit question renders inline math at phone width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, child: LatexText(repunitStem)),
        ),
      ),
    );
    expect(find.byType(Math), findsNWidgets(6));
    expect(find.textContaining(r'\(', findRichText: true), findsNothing);
    expect(find.textContaining('R_n', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  const solution =
      r'\text{Choosing a committee of 3 from 7 distinct people is a combination because order does not matter.}'
      r'\newline\binom{7}{3}=\frac{7!}{3!\,4!}=\frac{7\times6\times5}{3\times2\times1}=35.'
      r'\newline\text{Thus there are 35 possible committees.}';

  test(
    'bare solution separates wrapping prose and math without corrupting commands',
    () {
      final parts = parseLatexText(solution);
      expect(
        parts.where((p) => p.math).single.text,
        startsWith(r'\binom{7}{3}'),
      );
      final prose = parts.where((p) => !p.math).map((p) => p.text).join();
      expect(prose, contains('\nThus there are 35 possible committees.'));
      expect(prose, isNot(contains(r'\text')));
      expect(prose, isNot(contains('ewline')));
      expect(parseLatexText(r'$a\neq b$').single.text, r'a\neq b');
      expect(parseLatexText(r'\neq').single.text, r'\neq');
    },
  );

  testWidgets('committee solution renders math and wraps at phone width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 280, child: LatexText(solution))),
      ),
    );
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining(r'\binom', findRichText: true), findsNothing);
    expect(find.textContaining(r'\text', findRichText: true), findsNothing);
    expect(
      find.textContaining('35 possible committees', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  const moemsStem =
      r'The L-shaped figure below is formed by joining a 6\times4 rectangle '
      r'and a 3\times5 rectangle along a side of length 3. What is the '
      r'perimeter of the combined shape?';

  test('bare multiplication displays as a symbol in MOEMS prose', () {
    expect(
      parseLatexText(moemsStem).single.text,
      moemsStem.replaceAll(r'\times', '×'),
    );
    expect(parseLatexText(r'6\times 4').single.text, '6× 4');
    expect(parseLatexText(r'\timesExtra').single.text, r'\timesExtra');
  });

  test('delimited multiplication remains math', () {
    final parts = parseLatexText(r'A 6\times4 rectangle and $3\times5$.');
    expect(parts.first.text, 'A 6×4 rectangle and ');
    expect(parts.where((p) => p.math).single.text, r'3\times5');
  });

  testWidgets('MOEMS dimensions render without raw commands', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LatexText(moemsStem))),
    );
    expect(find.textContaining(r'\times', findRichText: true), findsNothing);
    expect(find.textContaining('6×4', findRichText: true), findsOneWidget);
    expect(find.textContaining('3×5', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('parseLatexText pulls a bare array out as display math', () {
    final parts = parseLatexText(_stem);
    final blocks = parts.where((p) => p.block).toList();
    expect(blocks, hasLength(1));
    expect(blocks.single.text, startsWith(r'\begin{array}{r'));
    expect(blocks.single.text, isNot(contains('@')));
    expect(
      parts.where((p) => !p.math).map((p) => p.text).join(),
      isNot(contains(r'\n')),
    );
    expect(parts.where((p) => p.math && !p.block).single.text, 'ABC');
  });

  testWidgets('bare array renders as math, not raw text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LatexText(_stem))),
    );
    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining('begin'), findsNothing);
  });
}
