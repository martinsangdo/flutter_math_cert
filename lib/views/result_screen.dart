import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/clay_card.dart';
import 'widgets/content_width.dart';

String _points(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

class ResultScreen extends ConsumerWidget {
  const ResultScreen(this.session, this.set, {super.key});

  final ExamSession session;
  final ExamSet set;

  /// The next unlocked set after [set] in the curated order, if any.
  ExamSet? _next(List<ExamSet> sets) {
    final i = sets.indexWhere((s) => s.id == set.id);
    return i < 0 ? null : sets.skip(i + 1).where((s) => !s.premium).firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = _next(ref.watch(examSetsProvider).valueOrNull ?? const []);
    void open(ExamSet s) => Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => QuizScreen(s)));

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final minutes = session.durationSeconds ~/ 60;
    final seconds = (session.durationSeconds % 60).toString().padLeft(2, '0');
    final weak = session.weakTopics;
    final topics = session.topics.values.toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final percent = (session.accuracy * 100).round();

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Your results')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            ClayCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Semantics(
                    label: '$percent percent accuracy',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 148,
                      height: 148,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: session.accuracy,
                              strokeWidth: 14,
                              strokeCap: StrokeCap.round,
                              color: session.passed ? scheme.success : scheme.primary,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$percent%', style: text.displayMedium?.copyWith(fontSize: 44)),
                              Text('accuracy', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(session.passed ? 'Great job!' : 'Good effort!', style: text.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    session.passed
                        ? 'You passed this practice exam.'
                        : 'A bit more practice and you will get there.',
                    style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(icon: Icons.stars_rounded, value: '${_points(session.score)}/${_points(session.maxScore)}', label: 'Points'),
                const SizedBox(width: 10),
                _Stat(icon: Icons.check_circle_rounded, value: '${session.correct}/${session.total}', label: 'Correct'),
                const SizedBox(width: 10),
                _Stat(icon: Icons.timer_rounded, value: '$minutes:$seconds', label: 'Time'),
              ],
            ),
            const SizedBox(height: 24),
            Text('Focus on these', style: text.titleLarge),
            const SizedBox(height: 12),
            ClayCard(
              color: weak.isEmpty ? null : scheme.secondaryContainer,
              borderColor: weak.isEmpty ? null : scheme.secondary,
              child: weak.isEmpty
                  ? Row(
                      children: [
                        Icon(Icons.verified_rounded, color: scheme.success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No weak topics. Every topic is at 60% or better.',
                            style: text.bodyLarge,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (final t in weak)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, color: scheme.onSecondaryContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: text.titleSmall?.copyWith(color: scheme.onSecondaryContainer),
                                  ),
                                ),
                                Text(
                                  '${t.correct}/${t.total}',
                                  style: text.titleSmall?.copyWith(color: scheme.onSecondaryContainer),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Text('Score by topic', style: text.titleLarge),
            const SizedBox(height: 12),
            ClayCard(
              child: Column(
                children: [
                  for (final t in topics)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Semantics(
                        label: '${t.name}, ${t.correct} of ${t.total} correct',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(t.name, style: text.titleSmall)),
                                Text('${t.correct}/${t.total}', style: text.titleSmall),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: t.accuracy,
                              color: t.accuracy >= 0.8
                                  ? scheme.success
                                  : t.accuracy >= 0.6
                                      ? scheme.primary
                                      : scheme.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (next != null) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => open(next),
                icon: const Icon(Icons.skip_next_rounded),
                label: Text('Next: ${next.title}', overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => open(set),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: (next == null ? FilledButton.icon : FilledButton.tonalIcon)(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Dashboard'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: ClayCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.accents[0], size: 26),
              const SizedBox(height: 6),
              FittedBox(child: Text(value, style: text.titleMedium)),
              Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
