import 'package:flutter/material.dart';

import '../models/models.dart';

String _points(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

class ResultScreen extends StatelessWidget {
  const ResultScreen(this.session, {super.key});

  final ExamSession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final minutes = session.durationSeconds ~/ 60;
    final seconds = session.durationSeconds % 60;
    final weak = session.weakTopics;
    final topics = session.topics.values.toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return Scaffold(
      appBar: AppBar(title: const Text('Results'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Text(
                '${_points(session.score)} / ${_points(session.maxScore)} pts',
                style: text.displayMedium,
              ),
            ),
            Center(
              child: Text(
                '${session.correct} of ${session.total} correct · '
                '${(session.accuracy * 100).round()}% · ${minutes}m ${seconds}s',
                style: text.titleMedium,
              ),
            ),
            Center(
              child: Chip(
                avatar: Icon(
                  session.passed ? Icons.check_circle : Icons.flag_outlined,
                  color: session.passed ? Colors.green : Colors.orange,
                ),
                label: Text(session.passed ? 'Passed' : 'Keep practicing'),
              ),
            ),
            const SizedBox(height: 24),
            Text('Weak topics', style: text.titleMedium),
            const SizedBox(height: 8),
            if (weak.isEmpty)
              const Text('None. Every topic is at 60% or better.')
            else
              for (final t in weak)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(t.name),
                  trailing: Text('${t.correct}/${t.total}'),
                ),
            const SizedBox(height: 16),
            Text('Score by topic', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final t in topics)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(t.name)),
                        Text('${t.correct}/${t.total}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: t.accuracy, minHeight: 8),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
